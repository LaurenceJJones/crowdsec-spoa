package.path = package.path .. ";./?.lua"

local utils = require "utils"
local template = require "template"

-- Template
-- @param path the path to the template
-- @return object with template and render function
local function NewTemplate(path)
    local self = {}
    self.template = utils.read_file(path)
    self.render = function(data)
        return template.compile(self.template, data)
    end
    return self
end

local function NewLogger(prefix)
    local self = {}
    self.prefix = prefix
    self.log = function(level, message)
        core.log(level, self.prefix .. message)
    end
    self.info = function(message)
        self.log(core.info, "[INFO] " .. message)
    end
    self.error = function(message)
        self.log(core.error, "[ERROR] " .. message)
    end
    self.warning = function(message)
        self.log(core.warning, "[WARN] " .. message)
    end
    self.debug = function(message)
        self.log(core.debug, "[DEBUG] " .. message)
    end
    return self
end

local runtime = {}

-- Loads the configuration
local function init()
    ban_template_path = os.getenv("CROWDSEC_BAN_TEMPLATE_PATH")
    captcha_template_path = os.getenv("CROWDSEC_CAPTCHA_TEMPLATE_PATH")
    crowdsec_log_level = os.getenv("CROWDSEC_LOG_LEVEL")
    runtime.logger = NewLogger("[crowdsec] ")
    runtime.logger.info("initialising lua modules")

    if ban_template_path == nil then
        runtime.logger.error("CROWDSEC_BAN_TEMPLATE_PATH env is not set")
        return
    end
    
    runtime.ban = NewTemplate(ban_template_path)
    
    if captcha_template_path == nil then
        runtime.logger.error("CROWDSEC_CAPTCHA_TEMPLATE_PATH env is not set")
        return
    end

    runtime.captcha = NewTemplate(captcha_template_path)
    runtime.logger.info("lua modules initialised")
end

-- Helper function to get a transaction variable
-- @param txn the transaction https://www.arpalert.org/src/haproxy-lua-api/2.9/index.html#txn-class
-- @param key the key to get
-- @return the value of the key or an empty string
local function get_txn_var(txn, key)
    local var = txn:get_var("txn."..key)
    if var == nil then
        return ""
    end
    return var
end

-- Render the remediation page
-- @param txn the transaction https://www.arpalert.org/src/haproxy-lua-api/2.9/index.html#txn-class
-- @return nil
function runtime.Handle(txn)
    local remediation = get_txn_var(txn, "crowdsec.remediation")
    local reply = txn:reply({ status = 403, body = "" })
    
    if remediation == "" then
        runtime.logger.error("No remediation found")
        return
    end
    
    -- Always disable cache
    reply:add_header("cache-control", "no-cache")
    reply:add_header("cache-control", "no-store")
    
    if remediation == "allow" then
        local redirect_uri = get_txn_var(txn, "crowdsec.redirect")
        if redirect_uri ~= "" then
            reply:set_status(302)
            reply:add_header("Location", redirect_uri)
        else
            return
        end
    end

    if remediation == "captcha" then
        reply:set_status(200)
        reply:set_body(runtime.captcha.render({
            ["captcha_site_key"]=get_txn_var(txn, "crowdsec.captcha_site_key"),
            ["captcha_frontend_key"]=get_txn_var(txn, "crowdsec.captcha_frontend_key"),
            ["captcha_frontend_js"]=get_txn_var(txn, "crowdsec.captcha_frontend_js"),
        }))
        local cookie = get_txn_var(txn, "crowdsec.captcha_cookie")
        if cookie ~= "" then
            reply:add_header("Set-Cookie", cookie)
        end
    end

    if remediation == "ban" then
        reply:set_body(runtime.ban.render({
            ["contact_us_url"]=get_txn_var(txn, "crowdsec.contact_us_url"),
        }))
    end

    
    local hdr = txn.http:req_get_headers()
    if hdr ~= nil and utils.accept_html(hdr) == false then
        reply:set_body("Forbidden")
        reply:add_header("Content-Type", "text/plain")
    else
        reply:add_header("Content-Type", "text/html")
    end
    reply:add_header("Content-Length", #reply.body)
    txn:done(reply)
end

-- Registers
core.register_init(init)
core.register_action("crowdsec_handle", {"http-req"}, runtime.Handle)