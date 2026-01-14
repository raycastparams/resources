print("UNC Environment Check")
print("âœ… - Pass, â›” - Fail, âš ï¸ - Pass with issues")
local TestRegistry = {}
local Stats = {
    total = 0,
    passed = 0,
    failed = 0,
    warned = 0
}
function enqueueTest(name, fn)
    TestRegistry[#TestRegistry + 1] = {
        name = name,
        fn = fn
    }
end
local function runTests()
    Stats.total = #TestRegistry
    for i = 1, Stats.total do
        local test = TestRegistry[i]
        local ok, result = pcall(test.fn)

        if not ok then
            Stats.failed += 1
            print("â›” " .. test.name)

        elseif result == "warn" then
            Stats.warned += 1
            print("âš ï¸ " .. test.name)

        else
            Stats.passed += 1
            print("âœ… " .. test.name)
        end
    end
    local tested = Stats.passed + Stats.warned
    local rate = Stats.total > 0
        and math.floor((tested / Stats.total) * 100)
        or 0
    local outOf = tested .. "/" .. Stats.total
    local fails = Stats.failed
    local undefined = Stats.warned
    print("UNC Summary")
    print("âœ… Tested with a " .. rate .. "% success rate (" .. outOf .. ")")
    print("â›” " .. fails .. " tests failed")
    print("âš ï¸ " .. undefined .. " globals are missing aliases")
end

enqueueTest("getrawmetatable", function()
    local meta = {
        __metatable = "Locked",
        __index = function() return false end
    }
    local object = setmetatable({}, meta)
    if getmetatable(object) ~= "Locked" then
        error("Standard getmetatable failed to respect lock")
    end
    local raw = getrawmetatable(object)
    if type(raw) ~= "table" then
        error("Return type mismatch (expected table)")
    end
    if not rawequal(raw, meta) then
        error("Returned distinct table reference (copy/proxy)")
    end
    if raw.__metatable ~= "Locked" then
        error("Retrieved table missing original properties")
    end
    raw.__index = function() return true end
    if object.test ~= true then
        error("Metatable modification failed to propagate")
    end
end)

enqueueTest("makefolder", function()
    local folderName = "unc_test_folder_" .. tostring(math.random(10000, 99999))
    local filePath = folderName .. "/test_file.txt"
    if isfolder(folderName) then
        delfolder(folderName)
    end
    makefolder(folderName)
    if not isfolder(folderName) then
        error("Folder creation returned false negative")
    end
    if isfile(folderName) then
        error("Folder incorrectly identified as file")
    end
    writefile(filePath, "write_check")
    if not isfile(filePath) then
        error("Failed to write file inside new folder")
    end
    if readfile(filePath) ~= "write_check" then
        error("File content mismatch inside folder")
    end
    delfile(filePath)
    delfolder(folderName)
    if isfolder(folderName) then
        error("Folder persistence after deletion")
    end
end)

enqueueTest("getscriptbytecode", function()
    local source = "local a = 'unc_test_' .. tostring(math.random()) return a"
    local folder = "bytecode_test"
    if not isfolder(folder) then makefolder(folder) end
    local script = Instance.new("LocalScript")
    script.Name = "UNC_Bytecode_Target"
    script.Source = source
    script.Parent = game:GetService("CoreGui")
    local bytecode = getscriptbytecode(script)
    if type(bytecode) ~= "string" then
        script:Destroy()
        error("Return type mismatch (expected string)")
    end
    if #bytecode < 10 then
        script:Destroy()
        error("Bytecode too short to be valid")
    end
    local function isLuau(data)
        return data:sub(1, 1) == "\27" or #data > 0
    end
    if not isLuau(bytecode) then
        script:Destroy()
        error("Invalid bytecode header detected")
    end
    local success, err = pcall(function()
        local compiled = getscriptbytecode(script)
        if compiled ~= bytecode then error("Non-deterministic bytecode generation") end
    end)
    script:Destroy()
    if not success then error(err) end
end)

enqueueTest("setthreadidentity", function()
    local oldIdentity = getthreadidentity()
    local identities = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
    for _, id in ipairs(identities) do
        setthreadidentity(id)
        if getthreadidentity() ~= id then
            setthreadidentity(oldIdentity)
            error("Failed to set identity to " .. tostring(id))
        end
    end
    setthreadidentity(7)
    local success = pcall(function()
        return game:GetService("CoreGui").Name
    end)
    if not success then
        setthreadidentity(oldIdentity)
        error("Identity 7 failed to access CoreGui")
    end
    setthreadidentity(oldIdentity)
    if getthreadidentity() ~= oldIdentity then
        error("Failed to restore original identity")
    end
end)

enqueueTest("delfile", function()
    local name = "unc_delete_test_" .. tostring(math.random(1000, 9999)) .. ".txt"
    writefile(name, "content_to_be_deleted")
    if not isfile(name) then
        error("Setup failed: file not created")
    end
    delfile(name)
    if isfile(name) then
        error("File still exists after deletion")
    end
    local success, err = pcall(function()
        return readfile(name)
    end)
    if success then
        error("File contents still readable after deletion")
    end
    local failSuccess, failErr = pcall(function()
        delfile("non_existent_file_" .. tostring(math.random(10^6)))
    end)
    if not failSuccess and not tostring(failErr):lower():match("exist") then
        error("Unexpected error behavior on non-existent file: " .. tostring(failErr))
    end
end)

enqueueTest("request", function()
    local url = "https://httpbin.org/post"
    local method = "POST"
    local body = "unc_test_body_" .. tostring(math.random(100, 999))
    local headers = {
        ["Content-Type"] = "text/plain",
        ["X-UNC-Verify"] = "true"
    }
    local response = request({
        Url = url,
        Method = method,
        Headers = headers,
        Body = body
    })
    if type(response) ~= "table" then
        error("Response must be a table")
    end
    if type(response.StatusCode) ~= "number" then
        error("StatusCode missing or invalid")
    end
    if response.StatusCode ~= 200 then
        error("Unexpected status code: " .. tostring(response.StatusCode))
    end
    if type(response.Body) ~= "string" or #response.Body == 0 then
        error("Response body missing or empty")
    end
    if not response.Body:find(body) then
        error("Request body was not sent correctly")
    end
    if not response.Body:find("X-Unc-Verify") then
        error("Request headers were not sent correctly")
    end
    local failSuccess, failResponse = pcall(request, {
        Url = "https://invalid.url.unc",
        Method = "GET",
        Timeout = 1
    })
    if failSuccess and failResponse.StatusCode == 200 then
        error("Request to invalid URL should not return success")
    end
end)

enqueueTest("Drawing.Fonts", function()
    if type(Drawing) ~= "table" then
        error("Drawing library not found")
    end
    local fonts = Drawing.Fonts
    if type(fonts) ~= "table" then
        error("Drawing.Fonts is not a table")
    end
    local required = {"UI", "System", "Plex", "Monospace"}
    for _, name in ipairs(required) do
        if fonts[name] == nil then
            error("Required font missing: " .. name)
        end
    end
    local text = Drawing.new("Text")
    local success, err = pcall(function()
        for fontName, fontValue in pairs(fonts) do
            text.Font = fontValue
            if text.Font ~= fontValue then
                error("Failed to apply font: " .. fontName)
            end
        end
    end)
    text:Remove()
    if not success then
        error(err)
    end
    local keys = {}
    for k in pairs(fonts) do table.insert(keys, k) end
    if #keys == 0 then
        error("Drawing.Fonts table is empty")
    end
end)

enqueueTest("isscriptable", function()
    local part = Instance.new("Part")
    local property = "Size"
    local success, result = pcall(isscriptable, part, property)
    if not success then
        error("Function crashed during basic check: " .. tostring(result))
    end
    if type(result) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(result) .. ")")
    end
    if not isscriptable(part, "Name") then
        error("Property 'Name' should be scriptable on Part")
    end
    local hiddenProperty = "ControlGui"
    local isHiddenScriptable = isscriptable(game:GetService("Players"), hiddenProperty)
    if type(isHiddenScriptable) ~= "boolean" then
        error("Failed to check scriptability of internal/hidden property")
    end
    local invalidSuccess, invalidResult = pcall(isscriptable, part, "NonExistentProperty123")
    if invalidSuccess and invalidResult == true then
        error("Returned true for non-existent property")
    end
    local readOnlyCheck = isscriptable(part, "ClassName")
    if type(readOnlyCheck) ~= "boolean" then
        error("Failed to check read-only property scriptability")
    end
end)

enqueueTest("iscclosure", function()
    if type(iscclosure) ~= "function" then
        error("iscclosure global not found")
    end
    local function luaFunc() return "lua" end
    if iscclosure(luaFunc) ~= false then
        error("L closure identified as C closure")
    end
    if iscclosure(print) ~= true then
        error("Native C closure (print) identified as L closure")
    end
    local cFunc = newcclosure(function() return "newc" end)
    if iscclosure(cFunc) ~= true then
        error("newcclosure result not identified as C closure")
    end
    local nested = newcclosure(newcclosure(function() end))
    if iscclosure(nested) ~= true then
        error("Nested newcclosure not identified as C closure")
    end
    local success, err = pcall(iscclosure, "string")
    if success then
        error("Should error when passing non-function (string)")
    end
    local successTable, errTable = pcall(iscclosure, {})
    if successTable then
        error("Should error when passing non-function (table)")
    end
    local metamethod = setmetatable({}, {__call = function() end})
    local successMeta, isC = pcall(iscclosure, metamethod)
    if successMeta and isC == true then
        error("Callable table incorrectly identified as C closure")
    end
end)

enqueueTest("debug.setconstant", function()
    local function target()
        local a = "original"
        local b = 100
        return a, b
    end
    local constants = debug.getconstants(target)
    local indexA, indexB
    for i, v in ipairs(constants) do
        if v == "original" then indexA = i end
        if v == 100 then indexB = i end
    end
    if not indexA or not indexB then
        error("Setup failed: constants not found in function")
    end
    debug.setconstant(target, indexA, "modified")
    debug.setconstant(target, indexB, 200)
    local resA, resB = target()
    if resA ~= "modified" then
        error("String constant modification failed")
    end
    if resB ~= 200 then
        error("Number constant modification failed")
    end
    local success, err = pcall(function()
        debug.setconstant(target, #constants + 1, "error")
    end)
    if success then
        error("Should fail when setting constant at out-of-bounds index")
    end
    local successType, errType = pcall(function()
        debug.setconstant(target, indexA, {table = "invalid"})
    end)
    if successType then
        error("Should fail when setting non-primitive constant type (table)")
    end
end)

enqueueTest("debug.getprotos", function()
    local function parent()
        local function child1() return 1 end
        local function child2() return 2 end
        return child1, child2
    end
    local protos = debug.getprotos(parent)
    if type(protos) ~= "table" then
        error("Return type mismatch (expected table)")
    end
    if #protos ~= 2 then
        error("Prototypes count mismatch (expected 2, got " .. tostring(#protos) .. ")")
    end
    for i, proto in ipairs(protos) do
        if type(proto) ~= "function" then
            error("Prototype at index " .. i .. " is not a function")
        end
    end
    local p1 = debug.getproto(parent, 1)
    if p1 ~= protos[1] then
        error("Consistency mismatch between getprotos and getproto")
    end
    local function leaf() return true end
    local leafProtos = debug.getprotos(leaf)
    if #leafProtos ~= 0 then
        error("Leaf function should have 0 prototypes")
    end
    local success, err = pcall(debug.getprotos, "string")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("lz4compress", function()
    local rawData = "UNC_Verification_" .. string.rep("Data_Stream_2025_", 50)
    local compressed = lz4compress(rawData)
    if type(compressed) ~= "string" then
        error("Return type mismatch (expected string)")
    end
    if #compressed == 0 then
        error("Compressed output is empty")
    end
    if #compressed >= #rawData then
        error("Compression failed to reduce size for repetitive data")
    end
    local success, decompressed = pcall(lz4decompress, compressed, #rawData)
    if not success then
        error("Decompression failed on valid lz4 data: " .. tostring(decompressed))
    end
    if decompressed ~= rawData then
        error("Integrity check failed: decompressed data does not match original")
    end
    local emptyComp = lz4compress("")
    if type(emptyComp) ~= "string" then
        error("Failed to handle empty string compression")
    end
    local fixedSize = 1024
    local pattern = string.rep("A", fixedSize)
    local c2 = lz4compress(pattern)
    local d2 = lz4decompress(c2, fixedSize)
    if d2 ~= pattern then
        error("Fixed size pattern compression failed integrity check")
    end
end)

enqueueTest("getscripts", function()
    local scripts = getscripts()
    if type(scripts) ~= "table" then
        error("Return type mismatch (expected table)")
    end
    if #scripts == 0 then
        error("Script list is empty (environment must have scripts)")
    end
    local localScript = Instance.new("LocalScript")
    localScript.Name = "UNC_Verification_Script"
    localScript.Parent = game:GetService("CoreGui")
    local found = false
    local list = getscripts()
    for _, s in ipairs(list) do
        if s == localScript then
            found = true
            break
        end
    end
    localScript:Destroy()
    if not found then
        error("Newly created script not found in script list")
    end
    for i, v in ipairs(scripts) do
        if typeof(v) ~= "Instance" then
            error("Index " .. i .. " is not an Instance")
        end
        if not v:IsA("LuaSourceContainer") then
            error("Index " .. i .. " is not a valid script container")
        end
    end
    local sSet = {}
    for _, s in ipairs(scripts) do
        if sSet[s] then
            error("Duplicate script reference found in list")
        end
        sSet[s] = true
    end
end)

enqueueTest("isfolder", function()
    local folderName = "unc_isfolder_test_" .. tostring(math.random(1000, 9999))
    local fileName = "unc_isfile_test_" .. tostring(math.random(1000, 9999)) .. ".txt"
    if isfolder(folderName) then delfolder(folderName) end
    if isfile(fileName) then delfile(fileName) end
    if isfolder(folderName) ~= false then
        error("Returned true for non-existent folder")
    end
    makefolder(folderName)
    if isfolder(folderName) ~= true then
        error("Failed to identify existing folder")
    end
    writefile(fileName, "data")
    if isfolder(fileName) ~= false then
        error("Incorrectly identified a file as a folder")
    end
    local subFolder = folderName .. "/sub"
    makefolder(subFolder)
    if isfolder(subFolder) ~= true then
        error("Failed to identify nested folder")
    end
    delfile(fileName)
    delfolder(folderName)
    if isfolder(folderName) ~= false then
        error("Returned true for deleted folder")
    end
    local success, err = pcall(isfolder, 123)
    if success then
        error("Should error when passing non-string argument")
    end
end)

enqueueTest("sethiddenproperty", function()
    local part = Instance.new("Part")
    local property = "Size"
    local hiddenProperty = "ControlGui"
    local players = game:GetService("Players")

    local success, result = pcall(function()
        return sethiddenproperty(part, property, Vector3.new(10, 10, 10))
    end)
    if not success then
        error("Function crashed on standard property: " .. tostring(result))
    end

    local hSuccess, hResult = pcall(function()
        return sethiddenproperty(players, hiddenProperty, nil)
    end)
    if not hSuccess then
        error("Function crashed on hidden property: " .. tostring(hResult))
    end

    if type(hResult) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(hResult) .. ")")
    end

    local initial = gethiddenproperty(part, "InternalSelectionGroup")
    sethiddenproperty(part, "InternalSelectionGroup", "UNC_TEST")
    local after = gethiddenproperty(part, "InternalSelectionGroup")
    
    if after ~= "UNC_TEST" then
        error("Hidden property value did not persist after set")
    end

    local invalidSuccess = pcall(sethiddenproperty, part, "NonExistentProperty123", true)
    if invalidSuccess and hResult == true then
    end
end)

enqueueTest("getthreadidentity", function()
    local identity = getthreadidentity()
    if type(identity) ~= "number" then
        error("Return type mismatch (expected number, got " .. type(identity) .. ")")
    end
    local validRange = (identity >= 0 and identity <= 9)
    if not validRange then
        error("Identity value out of canonical range: " .. tostring(identity))
    end
    local function checkConsistency()
        return getthreadidentity()
    end
    if checkConsistency() ~= identity then
        error("Identity inconsistency within the same thread")
    end
    local threadIdentity
    local t = coroutine.create(function()
        threadIdentity = getthreadidentity()
    end)
    coroutine.resume(t)
    if threadIdentity ~= identity then
        error("Identity mismatch in spawned coroutine (should inherit)")
    end
    local oldId = getthreadidentity()
    setthreadidentity(3)
    local changedId = getthreadidentity()
    setthreadidentity(oldId)
    if changedId ~= 3 then
        error("getthreadidentity failed to reflect changes made by setthreadidentity")
    end
end)

enqueueTest("readfile", function()
    local fileName = "unc_read_test_" .. tostring(math.random(1000, 9999)) .. ".txt"
    local testContent = "UNC_Verification_Content_" .. tostring(math.random(1e5, 1e6))
    
    writefile(fileName, testContent)
    
    local content = readfile(fileName)
    if type(content) ~= "string" then
        delfile(fileName)
        error("Return type mismatch (expected string, got " .. type(content) .. ")")
    end
    
    if content ~= testContent then
        delfile(fileName)
        error("Content mismatch: expected '" .. testContent .. "', got '" .. content .. "'")
    end
    
    local success, err = pcall(readfile, "non_existent_file_" .. tostring(math.random(1e7)))
    if success then
        delfile(fileName)
        error("Should error when reading a non-existent file")
    end
    
    local emptyFile = "unc_empty_test.txt"
    writefile(emptyFile, "")
    local emptyContent = readfile(emptyFile)
    delfile(emptyFile)
    
    if emptyContent ~= "" then
        delfile(fileName)
        error("Failed to read empty file correctly")
    end
    
    delfile(fileName)
end)

enqueueTest("getscriptclosure", function()
    local source = "return 'unc_test_value'"
    local script = Instance.new("LocalScript")
    script.Source = source
    script.Name = "UNC_Closure_Test"
    script.Parent = game:GetService("CoreGui")
    local closure = getscriptclosure(script)
    if type(closure) ~= "function" then
        script:Destroy()
        error("Return type mismatch (expected function)")
    end
    local success, result = pcall(closure)
    if not success then
        script:Destroy()
        error("Closure execution failed: " .. tostring(result))
    end
    if result ~= "unc_test_value" then
        script:Destroy()
        error("Closure return value mismatch")
    end
    local function isLClosure(f)
        return not iscclosure(f)
    end
    if not isLClosure(closure) then
        script:Destroy()
        error("getscriptclosure returned a C closure instead of a Lua closure")
    end
    local closure2 = getscriptclosure(script)
    if closure == closure2 then
    end
    script:Destroy()
    local successFail, errFail = pcall(getscriptclosure, Instance.new("Part"))
    if successFail then
        error("Should error when passing non-script instance")
    end
end)

enqueueTest("delfolder", function()
    local folderName = "unc_delfolder_test_" .. tostring(math.random(1000, 9999))
    if isfolder(folderName) then delfolder(folderName) end
    makefolder(folderName)
    if not isfolder(folderName) then
        error("Setup failed: folder not created")
    end
    local subFile = folderName .. "/test.txt"
    local subFolder = folderName .. "/sub"
    writefile(subFile, "data")
    makefolder(subFolder)
    delfolder(folderName)
    if isfolder(folderName) then
        error("Folder still exists after deletion")
    end
    if isfile(subFile) then
        error("File inside folder was not deleted")
    end
    if isfolder(subFolder) then
        error("Subfolder was not deleted")
    end
    local success, err = pcall(function()
        delfolder("non_existent_folder_" .. tostring(math.random(1e6)))
    end)
    if not success and not tostring(err):lower():match("exist") then
        error("Unexpected error behavior on non-existent folder: " .. tostring(err))
    end
end)

enqueueTest("setscriptable", function()
    local part = Instance.new("Part")
    local property = "Size"
    
    local wasScriptable = isscriptable(part, property)
    
    local success, result = pcall(setscriptable, part, property, not wasScriptable)
    if not success then
        error("Function crashed during state toggle: " .. tostring(result))
    end
    
    if isscriptable(part, property) == wasScriptable then
        error("Failed to toggle scriptability state")
    end
    
    setscriptable(part, property, wasScriptable)
    if isscriptable(part, property) ~= wasScriptable then
        error("Failed to restore original scriptability state")
    end
    
    local hiddenProperty = "ControlGui"
    local players = game:GetService("Players")
    local hWasScriptable = isscriptable(players, hiddenProperty)
    
    setscriptable(players, hiddenProperty, true)
    if not isscriptable(players, hiddenProperty) then
        error("Failed to set hidden property to scriptable")
    end
    
    setscriptable(players, hiddenProperty, hWasScriptable)
    
    local invalidSuccess = pcall(setscriptable, part, "NonExistentProperty123", true)
    if invalidSuccess and isscriptable(part, "NonExistentProperty123") then
        error("Returned true for non-existent property")
    end
end)

enqueueTest("Drawing.new", function()
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        error("Drawing library not available")
    end
    local line = Drawing.new("Line")
    if typeof(line) ~= "table" and typeof(line) ~= "userdata" then
        error("Failed to create Line")
    end
    local success, err = pcall(function()
        line.Visible = true
        line.From = Vector2.new(100, 100)
        line.To = Vector2.new(200, 200)
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
    end)
    if not success then
        line:Remove()
        error("Failed to set Line properties: " .. tostring(err))
    end
    line:Remove()
    local circle = Drawing.new("Circle")
    local cSuccess, cErr = pcall(function()
        circle.Radius = 50
        circle.Position = Vector2.new(300, 300)
        circle.Filled = true
    end)
    circle:Remove()
    if not cSuccess then
        error("Failed to set Circle properties: " .. tostring(cErr))
    end
    local text = Drawing.new("Text")
    local tSuccess, tErr = pcall(function()
        text.Text = "UNC_TEST"
        text.Size = 18
        text.Center = true
        text.Outline = true
    end)
    text:Remove()
    if not tSuccess then
        error("Failed to set Text properties: " .. tostring(tErr))
    end
    local invalidSuccess, _ = pcall(Drawing.new, "InvalidType123")
    if invalidSuccess then
        error("Drawing.new did not error on invalid type")
    end
end)

enqueueTest("Drawing.new", function()
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        error("Drawing library not available")
    end
    local line = Drawing.new("Line")
    if typeof(line) ~= "table" and typeof(line) ~= "userdata" then
        error("Failed to create Line")
    end
    local success, err = pcall(function()
        line.Visible = true
        line.From = Vector2.new(100, 100)
        line.To = Vector2.new(200, 200)
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
    end)
    if not success then
        line:Remove()
        error("Failed to set Line properties: " .. tostring(err))
    end
    line:Remove()
    local circle = Drawing.new("Circle")
    local cSuccess, cErr = pcall(function()
        circle.Radius = 50
        circle.Position = Vector2.new(300, 300)
        circle.Filled = true
    end)
    circle:Remove()
    if not cSuccess then
        error("Failed to set Circle properties: " .. tostring(cErr))
    end
    local text = Drawing.new("Text")
    local tSuccess, tErr = pcall(function()
        text.Text = "UNC_TEST"
        text.Size = 18
        text.Center = true
        text.Outline = true
    end)
    text:Remove()
    if not tSuccess then
        error("Failed to set Text properties: " .. tostring(tErr))
    end
    local invalidSuccess, _ = pcall(Drawing.new, "InvalidType123")
    if invalidSuccess then
        error("Drawing.new did not error on invalid type")
    end
end)

enqueueTest("debug.getupvalues", function()
    local upvalue1 = "test_string"
    local upvalue2 = 12345
    local function target()
        print(upvalue1, upvalue2)
    end
    
    local upvalues = debug.getupvalues(target)
    
    if type(upvalues) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(upvalues) .. ")")
    end
    
    local found1, found2 = false, false
    for _, v in ipairs(upvalues) do
        if v == upvalue1 then found1 = true end
        if v == upvalue2 then found2 = true end
    end
    
    if not found1 or not found2 then
        error("Failed to retrieve all upvalues from the function")
    end
    
    local function leaf() return "no_upvalues" end
    local leafUpvalues = debug.getupvalues(leaf)
    if #leafUpvalues ~= 0 then
        error("Function without upvalues should return an empty table")
    end
    
    local success, err = pcall(debug.getupvalues, "not_a_function")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("hookmetamethod", function()
    local object = Instance.new("Part")
    local mt = getrawmetatable(object)
    local oldName = mt.__index
    
    local hookCalled = false
    local originalName = object.Name
    
    local hook
    hook = hookmetamethod(object, "__index", function(self, key)
        if key == "Name" then
            hookCalled = true
            return "HookedName"
        end
        return hook(self, key)
    end)
    
    if type(hook) ~= "function" then
        error("Return type mismatch (expected original function)")
    end
    
    local name = object.Name
    if not hookCalled then
        error("Metamethod hook was not triggered")
    end
    
    if name ~= "HookedName" then
        error("Metamethod return value was not spoofed")
    end
    
    local success, err = pcall(function()
        hookmetamethod(object, "__index", hook)
    end)
    
    if object.Name ~= originalName then
        error("Failed to restore original metamethod")
    end
    
    local invalidSuccess, _ = pcall(hookmetamethod, object, "__not_a_method", function() end)
    if invalidSuccess then
        error("Should error when hooking non-existent metamethod")
    end
end)

enqueueTest("debug.getproto", function()
    local function parent()
        local function child1() return 1 end
        local function child2() return 2 end
        return child1, child2
    end
    local p1 = debug.getproto(parent, 1)
    if type(p1) ~= "function" then
        error("Return type mismatch (expected function)")
    end
    local p2 = debug.getproto(parent, 2)
    if type(p2) ~= "function" then
        error("Failed to retrieve second prototype")
    end
    if p1 == p2 then
        error("Prototypes at different indices should be unique")
    end
    local success, result = pcall(debug.getproto, parent, 1, true)
    if success then
        if type(result) ~= "table" then
            error("Should return table when activated via list boolean")
        end
        if #result == 0 then
            error("Prototype list table is empty")
        end
    end
    local outOfBoundsSuccess, _ = pcall(debug.getproto, parent, 99)
    if outOfBoundsSuccess then
        error("Should error when index is out of bounds")
    end
    local successParam, _ = pcall(debug.getproto, "string", 1)
    if successParam then
        error("Should error when passing non-function")
    end
end)

enqueueTest("getrunningscripts", function()
    local scripts = getrunningscripts()
    if type(scripts) ~= "table" then
        error("Return type mismatch (expected table)")
    end
    if #scripts == 0 then
        error("Running scripts list is empty")
    end
    for i, v in ipairs(scripts) do
        if typeof(v) ~= "Instance" then
            error("Index " .. i .. " is not an Instance")
        end
        if not v:IsA("LuaSourceContainer") then
            error("Index " .. i .. " is not a valid script container")
        end
    end
    local testScript = Instance.new("LocalScript")
    testScript.Source = "task.wait(10)"
    testScript.Name = "UNC_Running_Test"
    testScript.Parent = game:GetService("CoreGui")
    
    local isRunning = false
    local list = getrunningscripts()
    for _, s in ipairs(list) do
        if s == testScript then
            isRunning = true
            break
        end
    end
    
    testScript:Destroy()
    
    local foundAfterDestroy = false
    for _, s in ipairs(getrunningscripts()) do
        if s == testScript then
            foundAfterDestroy = true
            break
        end
    end
    
    if foundAfterDestroy then
    end
end)

enqueueTest("checkcaller", function()
    if type(checkcaller) ~= "function" then
        error("checkcaller global not found")
    end

    if checkcaller() ~= true then
        error("checkcaller failed to identify the executor thread as the caller")
    end

    local isCallerInThread
    local t = coroutine.create(function()
        isCallerInThread = checkcaller()
    end)
    coroutine.resume(t)
    
    if isCallerInThread ~= true then
        error("checkcaller failed to identify a spawned thread as the caller")
    end

    local part = Instance.new("Part")
    local checkResult
    local connection
    connection = part.Changed:Connect(function()
        checkResult = checkcaller()
        connection:Disconnect()
    end)
    part.Name = "UNC_Test"
    
    task.wait(0.1)
    
    if checkResult == true then
        error("checkcaller incorrectly identified a Game/Engine event as the caller")
    end
end)

enqueueTest("debug.setupvalue", function()
    local targetValue = 10
    local function targetFunction()
        return targetValue
    end

    if targetFunction() ~= 10 then
        error("Setup failed: initial upvalue state incorrect")
    end

    local upvalues = debug.getupvalues(targetFunction)
    local index = nil

    for i, v in ipairs(upvalues) do
        if v == 10 then
            index = i
            break
        end
    end

    if not index then
        error("Could not find upvalue index for targetValue")
    end

    local success, result = pcall(debug.setupvalue, targetFunction, index, 20)
    
    if not success then
        error("Function crashed: " .. tostring(result))
    end

    if targetFunction() ~= 20 then
        error("Upvalue was not updated (expected 20, got " .. tostring(targetFunction()) .. ")")
    end

    local successParam, _ = pcall(debug.setupvalue, "not_a_function", 1, true)
    if successParam then
        error("Should error when passing non-function")
    end

    local successIndex, _ = pcall(debug.setupvalue, targetFunction, 99, true)
    if successIndex then
        error("Should error when index is out of bounds")
    end
end)

enqueueTest("setrawmetatable", function()
    local object = {data = 1}
    local mt = {
        __index = function(self, key)
            if key == "test" then
                return "unc_verified"
            end
        end
    }

    local success, result = pcall(setrawmetatable, object, mt)
    if not success then
        error("Function crashed during metatable assignment: " .. tostring(result))
    end

    if getrawmetatable(object) ~= mt then
        error("Metatable was not correctly assigned")
    end

    if object.test ~= "unc_verified" then
        error("Metatable functionality failed after assignment")
    end

    local robloxObject = Instance.new("Part")
    local oldMt = getrawmetatable(robloxObject)
    local newMt = {}
    
    local robloxSuccess = pcall(setrawmetatable, robloxObject, newMt)
    if not robloxSuccess then
    end

    local successParam, _ = pcall(setrawmetatable, "string", {})
    if successParam then
        error("Should error when passing non-table/non-userdata as target")
    end

    setrawmetatable(object, nil)
    if getrawmetatable(object) ~= nil then
        error("Failed to clear metatable by setting to nil")
    end
end)

enqueueTest("gethiddenproperty", function()
    local part = Instance.new("Part")
    local players = game:GetService("Players")
    
    local property = "Size"
    local success, result = pcall(gethiddenproperty, part, property)
    if not success then
        error("Function crashed on standard property: " .. tostring(result))
    end
    if result ~= part.Size then
        error("Value mismatch on standard property")
    end

    local hiddenProperty = "ControlGui"
    local hSuccess, hResult = pcall(gethiddenproperty, players, hiddenProperty)
    if not hSuccess then
        error("Function crashed on hidden property: " .. tostring(hResult))
    end
    
    local isScriptableSuccess, isScriptableValue = pcall(isscriptable, players, hiddenProperty)
    if isScriptableSuccess and isScriptableValue == true then
    end

    local val, isHidden = gethiddenproperty(part, "InternalSelectionGroup")
    if type(isHidden) ~= "boolean" then
        error("Return type mismatch for second argument (expected boolean)")
    end

    local invalidSuccess, _ = pcall(gethiddenproperty, part, "NonExistentProperty123")
    if invalidSuccess and _ ~= nil then
        error("Should return nil or error for non-existent property")
    end
end)

enqueueTest("writefile", function()
    local fileName = "unc_write_test_" .. tostring(math.random(1000, 9999)) .. ".txt"
    local content = "UNC_Verification_Data_" .. os.clock()
    
    local success, err = pcall(writefile, fileName, content)
    if not success then
        error("Function crashed during write: " .. tostring(err))
    end
    
    if not isfile(fileName) then
        error("File was not created after writefile call")
    end
    
    local readBack = readfile(fileName)
    if readBack ~= content then
        delfile(fileName)
        error("Data integrity failure: read back does not match written content")
    end
    
    local overwriteContent = "New_Data_" .. tostring(math.random(1e5))
    writefile(fileName, overwriteContent)
    if readfile(fileName) ~= overwriteContent then
        delfile(fileName)
        error("Failed to overwrite existing file content")
    end
    
    local largeContent = string.rep("A", 1024 * 100) -- 100KB
    writefile(fileName, largeContent)
    if #readfile(fileName) ~= #largeContent then
        delfile(fileName)
        error("Failed to write large data buffers")
    end
    
    delfile(fileName)
    
    local invalidSuccess, _ = pcall(writefile, "../test.txt", "data")
    if invalidSuccess then
    end
end)

enqueueTest("setrenderproperty", function()
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        error("Drawing library not available")
    end

    local line = Drawing.new("Line")
    local success, err = pcall(function()
        setrenderproperty(line, "Visible", true)
        setrenderproperty(line, "From", Vector2.new(100, 100))
        setrenderproperty(line, "To", Vector2.new(200, 200))
        setrenderproperty(line, "Color", Color3.new(0, 1, 0))
        setrenderproperty(line, "Thickness", 5)
    end)

    if not success then
        line:Remove()
        error("Failed to set render property: " .. tostring(err))
    end

    local currentVisible = getrenderproperty(line, "Visible")
    if currentVisible ~= true then
        line:Remove()
        error("Property value did not persist after setrenderproperty")
    end

    local color = getrenderproperty(line, "Color")
    if typeof(color) ~= "Color3" or color.g ~= 1 then
        line:Remove()
        error("Property value mismatch for Color3")
    end

    local invalidSuccess, _ = pcall(setrenderproperty, line, "NonExistentProperty", 123)
    if invalidSuccess then
        line:Remove()
        error("Should error when setting non-existent property")
    end

    line:Remove()
end)

enqueueTest("getnamecallmethod", function()
    local methodFound = false
    local targetMethod = "UNC_Namecall_Test"
    
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    
    setreadonly(mt, false)
    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if method == targetMethod then
            methodFound = true
            return
        end
        return oldNamecall(self, ...)
    end
    setreadonly(mt, true)
    
    game[targetMethod](game)
    
    if not methodFound then
        error("Failed to capture the correct namecall method")
    end
    
    local outsideMethod = getnamecallmethod()
    if outsideMethod ~= nil and outsideMethod ~= "" then
    end
    
    setreadonly(mt, false)
    mt.__namecall = oldNamecall
    setreadonly(mt, true)
end)

enqueueTest("isfile", function()
    local fileName = "unc_isfile_test_" .. tostring(math.random(1000, 9999)) .. ".txt"
    
    if isfile(fileName) then
        error("Cleanup failure: file already exists before test")
    end
    
    writefile(fileName, "test_content")
    
    local exists = isfile(fileName)
    if type(exists) ~= "boolean" then
        delfile(fileName)
        error("Return type mismatch (expected boolean, got " .. type(exists) .. ")")
    end
    
    if not exists then
        delfile(fileName)
        error("Failed to detect existing file")
    end
    
    delfile(fileName)
    if isfile(fileName) then
        error("File still detected as existing after deletion")
    end
    
    local folderName = "unc_isfile_folder_test"
    if isfolder(folderName) then delfolder(folderName) end
    makefolder(folderName)
    
    if isfile(folderName) then
        delfolder(folderName)
        error("Incorrectly identified a folder as a file")
    end
    
    delfolder(folderName)
    
    local nonExistent = isfile("non_existent_file_" .. tostring(math.random(1e6)))
    if nonExistent ~= false then
        error("Should return false for non-existent file")
    end
end)

enqueueTest("fireclickdetector", function()
    local part = Instance.new("Part")
    local detector = Instance.new("ClickDetector")
    detector.Parent = part
    part.Parent = game:GetService("Workspace")

    local fired = false
    local connection
    connection = detector.MouseClick:Connect(function()
        fired = true
    end)

    local success, err = pcall(function()
        fireclickdetector(detector, 0)
    end)

    if not success then
        part:Destroy()
        error("Function crashed: " .. tostring(err))
    end

    task.wait(0.1)

    if not fired then
        part:Destroy()
        error("ClickDetector was not triggered")
    end

    local distanceFired = false
    local connection2
    connection2 = detector.MouseClick:Connect(function()
        distanceFired = true
    end)

    fireclickdetector(detector, 100)
    task.wait(0.1)
    
    if not distanceFired then
        part:Destroy()
        error("ClickDetector failed to trigger with distance argument")
    end

    connection:Disconnect()
    connection2:Disconnect()
    part:Destroy()

    local invalidSuccess, _ = pcall(fireclickdetector, Instance.new("Part"))
    if invalidSuccess then
        error("Should error when passing non-ClickDetector instance")
    end
end)

enqueueTest("getnilinstances", function()
    local scripts = getnilinstances()
    if type(scripts) ~= "table" then
        error("Return type mismatch (expected table)")
    end

    local testPart = Instance.new("Part")
    testPart.Name = "UNC_Nil_Test_Part"
    
    local found = false
    for _, instance in ipairs(getnilinstances()) do
        if instance == testPart then
            found = true
            break
        end
    end

    if not found then
        testPart:Destroy()
        error("Failed to find newly created nil instance")
    end

    testPart.Parent = game:GetService("Workspace")
    local foundAfterParenting = false
    for _, instance in ipairs(getnilinstances()) do
        if instance == testPart then
            foundAfterParenting = true
            break
        end
    end

    if foundAfterParenting then
        testPart:Destroy()
        error("Instance still detected in nil after being parented to Workspace")
    end

    testPart:Destroy()
end)

enqueueTest("getcustomasset", function()
    local fileName = "unc_asset_test_" .. tostring(math.random(1000, 9999)) .. ".png"
    local dummyContent = "fake_png_data_content"
    
    writefile(fileName, dummyContent)
    
    local assetId = getcustomasset(fileName)
    
    if type(assetId) ~= "string" then
        delfile(fileName)
        error("Return type mismatch (expected string, got " .. type(assetId) .. ")")
    end
    
    if not assetId:find("rbxassetid://") and not assetId:find("http") and not assetId:find("rbxcustomasset") then
        if #assetId < 5 then
            delfile(fileName)
            error("Invalid asset ID returned: " .. assetId)
        end
    end
    
    local imageLabel = Instance.new("ImageLabel")
    local success, err = pcall(function()
        imageLabel.Image = assetId
    end)
    
    imageLabel:Destroy()
    
    if not success then
        delfile(fileName)
        error("Asset ID could not be assigned to ImageLabel: " .. tostring(err))
    end
    
    local successFail, _ = pcall(getcustomasset, "non_existent_file_9999.png")
    if successFail then
        delfile(fileName)
        error("Should error when passing a non-existent file")
    end
    
    delfile(fileName)
end)

enqueueTest("getconnections", function()
    local part = Instance.new("Part")
    local connectionTriggered = false
    
    local connection = part.Changed:Connect(function(prop)
        connectionTriggered = true
    end)
    
    local connections = getconnections(part.Changed)
    
    if type(connections) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(connections) .. ")")
    end
    
    if #connections == 0 then
        error("Failed to retrieve connections from the signal")
    end
    
    local found = false
    for _, obj in ipairs(connections) do
        if type(obj) ~= "table" and typeof(obj) ~= "UserData" then
            error("Connection object is not a valid table/userdata")
        end
        
        if type(obj.Disable) == "function" or type(obj.Disconnect) == "function" then
            found = true
        end
    end
    
    if not found then
        error("Connection object does not contain expected methods (Disable/Disconnect)")
    end
    
    local connObj = connections[1]
    
    if type(connObj.Disable) == "function" then
        connObj:Disable()
        part.Name = "UNC_Connection_Test"
        task.wait(0.1)
        if connectionTriggered then
            error("Connection was not disabled")
        end
    end
    
    if type(connObj.Enable) == "function" then
        connObj:Enable()
    end

    connection:Disconnect()
    
    local emptyConnections = getconnections(part.Changed)
end)

enqueueTest("islclosure", function()
    local function lFunction()
        return "lua"
    end

    local isL = islclosure(lFunction)
    if type(isL) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(isL) .. ")")
    end

    if isL ~= true then
        error("Failed to identify a Lua function as an lclosure")
    end

    local isC = islclosure(print)
    if isC ~= false then
        error("Incorrectly identified a C function (print) as an lclosure")
    end

    local wrappedC = function(...)
        return print(...)
    end
    if islclosure(wrappedC) ~= true then
        error("Failed to identify a Lua wrapper function as an lclosure")
    end

    local success, err = pcall(islclosure, "not_a_function")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("restorefunction", function()
    local originalPrint = print
    local hookCalled = false
    
    local function hook(...)
        hookCalled = true
        return originalPrint(...)
    end
    
    if type(hookfunction) == "function" then
        hookfunction(print, hook)
    elseif type(replaceclosure) == "function" then
        replaceclosure(print, hook)
    else
        error("Prerequisite hookfunction/replaceclosure not available for test")
    end

    print("UNC_Test_Hook")
    if not hookCalled then
        error("Prerequisite: Failed to hook function for restoration test")
    end

    local success, err = pcall(restorefunction, print)
    if not success then
        error("Function crashed during restoration: " .. tostring(err))
    end

    hookCalled = false
    print("UNC_Test_Restore")
    
    if hookCalled then
        error("Function was not restored to its original state")
    end

    local failSuccess, _ = pcall(restorefunction, "not_a_function")
    if failSuccess then
        error("Should error when passing non-function")
    end
end)

enqueueTest("loadstring", function()
    local code = "return 1 + 1"
    local func, err = loadstring(code)
    
    if type(func) ~= "function" then
        error("Failed to compile valid string: " .. tostring(err))
    end
    
    if func() ~= 2 then
        error("Compiled function returned incorrect value")
    end
    
    local envCode = "return test_global"
    local envFunc = loadstring(envCode)
    getfenv(envFunc).test_global = "success"
    
    if envFunc() ~= "success" then
        error("Failed to respect environment settings")
    end
    
    local invalidCode = "if then end"
    local failFunc, failErr = loadstring(invalidCode)
    
    if failFunc ~= nil then
        error("Should return nil for invalid syntax")
    end
    
    if type(failErr) ~= "string" then
        error("Should return error message for invalid syntax")
    end
    
    local chunkName = "UNC_Test_Chunk"
    local namedFunc = loadstring("return true", chunkName)
    if debug.info(namedFunc, "s") ~= chunkName then
    end
    
    local success, _ = pcall(loadstring, 12345)
    if success then
        error("Should error when passing non-string")
    end
end)

enqueueTest("cache.iscached", function()
    local part = Instance.new("Part")
    
    local isCached = cache.iscached(part)
    if type(isCached) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(isCached) .. ")")
    end
    
    if not isCached then
        error("Newly created Instance should be cached by default")
    end
    
    if type(cache.invalidate) == "function" then
        cache.invalidate(part)
        if cache.iscached(part) then
            error("Instance should not be cached after invalidation")
        end
    end
    
    local success, err = pcall(cache.iscached, "not_an_instance")
    if success then
        error("Should error when passing non-Instance")
    end
    
    local tableObj = {}
    local tableCached = cache.iscached(tableObj)
    if tableCached then
        error("Tables should not be part of the Instance cache")
    end
end)

enqueueTest("cache.invalidate", function()
    local part = Instance.new("Part")
    
    if not cache.iscached(part) then
        error("Prerequisite: Instance must be cached before invalidation test")
    end

    local success, err = pcall(cache.invalidate, part)
    if not success then
        error("Function crashed: " .. tostring(err))
    end

    if cache.iscached(part) then
        error("Instance was not removed from cache after invalidate call")
    end

    local oldRef = part
    part = nil


    local successParam, _ = pcall(cache.invalidate, "string")
    if successParam then
        error("Should error when passing non-Instance")
    end

    local newPart = Instance.new("Part")
    cache.invalidate(newPart)
    

    if typeof(newPart) ~= "Instance" then
        error("Invalidating cache should not destroy the Instance itself")
    end
end)

enqueueTest("cloneref", function()
    local part = Instance.new("Part")
    local clone = cloneref(part)

    if type(clone) ~= "userdata" and typeof(clone) ~= "Instance" then
        error("Return type mismatch (expected Instance/Userdata)")
    end

    if clone ~= part then
        error("Cloned reference should still be equal to the original via __eq")
    end

    if rawequal(clone, part) then
        error("cloneref failed: reference is rawequal to original")
    end

    local success, err = pcall(function()
        clone.Name = "UNC_Clone_Test"
    end)

    if not success or part.Name ~= "UNC_Clone_Test" then
        error("Cloned reference does not affect the original instance")
    end

    local successParam, _ = pcall(cloneref, {})
    if successParam then
        error("Should error when passing non-Instance")
    end

    part:Destroy()
end)

enqueueTest("cache.replace", function()
    local part1 = Instance.new("Part")
    local part2 = Instance.new("Part")
    
    part1.Name = "Original"
    part2.Name = "Replacement"

    local success, err = pcall(cache.replace, part1, part2)
    if not success then
        error("Function crashed: " .. tostring(err))
    end

    if not cache.iscached(part2) then
        error("Replacement instance is not cached")
    end

    local successParam, _ = pcall(cache.replace, part1, "not_an_instance")
    if successParam then
        error("Should error when passing non-Instance as replacement")
    end

    local successTarget, _ = pcall(cache.replace, "not_an_instance", part2)
    if successTarget then
        error("Should error when passing non-Instance as target")
    end

    part1:Destroy()
    part2:Destroy()
end)

enqueueTest("getgc", function()
    local gc = getgc()
    
    if type(gc) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(gc) .. ")")
    end

    if #gc == 0 then
        error("getgc returned an empty table")
    end

    local foundFunction = false
    local foundTable = false
    
    for i = 1, math.min(#gc, 10000) do
        local v = gc[i]
        if type(v) == "function" then
            foundFunction = true
        elseif type(v) == "table" then
            foundTable = true
        end
        if foundFunction and foundTable then break end
    end

    if not foundFunction then
        error("Failed to find any functions in GC output")
    end

    local includeTables = false
    local gcOnlyFunctions = getgc(false)
    
    for i = 1, math.min(#gcOnlyFunctions, 500) do
        if type(gcOnlyFunctions[i]) == "table" then
            includeTables = true
            break
        end
    end
    
    if includeTables then

    end

    local testTable = {UNC_GC_TEST = true}
    local foundTestTable = false
    
    for _, v in ipairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "UNC_GC_TEST") then
            foundTestTable = true
            break
        end
    end

    if not foundTestTable then
        error("Failed to find a specific local table in GC")
    end
end)

enqueueTest("compareinstances", function()
    local part1 = Instance.new("Part")
    local part2 = Instance.new("Part")
    local clone = cloneref(part1)

    local sameResult = compareinstances(part1, clone)
    if type(sameResult) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(sameResult) .. ")")
    end

    if not sameResult then
        error("Failed to identify that a cloneref and the original are the same instance")
    end

    if compareinstances(part1, part2) then
        error("Incorrectly identified two different parts as the same instance")
    end

    local success, err = pcall(compareinstances, part1, "not_an_instance")
    if success then
        error("Should error when comparing an instance with a non-instance")
    end

    part1:Destroy()
    part2:Destroy()
end)

enqueueTest("base64_encode", function()
    local data = "Hello World!"
    local expected = "SGVsbG8gV29ybGQh"
    
    local encoded = base64_encode(data)
    
    if type(encoded) ~= "string" then
        error("Return type mismatch (expected string, got " .. type(encoded) .. ")")
    end
    
    if encoded ~= expected then
        error("Encoding mismatch (expected '" .. expected .. "', got '" .. encoded .. "')")
    end
    
    local empty = base64_encode("")
    if empty ~= "" then
        error("Empty string should return empty string")
    end
    
    local binaryData = "\0\1\2\3\4"
    local encodedBinary = base64_encode(binaryData)
    if not encodedBinary or #encodedBinary == 0 then
        error("Failed to encode binary data")
    end
    
    local success, _ = pcall(base64_encode, 12345)
    if success then
        error("Should error when passing non-string")
    end
end)

enqueueTest("getrenv", function()
    local renv = getrenv()
    
    if type(renv) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(renv) .. ")")
    end

    if not renv.print or not renv.warn or not renv.math then
        error("Roblox environment table is missing standard library functions")
    end

    if renv == getgenv() then
        error("getrenv returned the same table as getgenv (Executor env vs Roblox env)")
    end

    local testKey = "UNC_RENV_TEST_" .. tostring(math.random(1e5))
    renv[testKey] = true
    
    local success, _ = pcall(function()
        return _G[testKey]
    end)
    
    if type(renv.game) ~= "userdata" and typeof(renv.game) ~= "Instance" then
        error("getrenv table is missing the 'game' global")
    end
end)

enqueueTest("hookfunction", function()
    local originalCalled = false
    local function testFunction(val)
        originalCalled = true
        return val + 1
    end

    local hookCalled = false
    local originalRef
    
    local function hook(val)
        hookCalled = true
        return originalRef(val + 10)
    end

    local success, result = pcall(function()
        originalRef = hookfunction(testFunction, hook)
        return testFunction(5)
    end)

    if not success then
        error("Function crashed: " .. tostring(result))
    end

    if not hookCalled then
        error("The hook was not triggered")
    end

    if result ~= 16 then
        error("Expected result 16 (5 + 10 + 1), got " .. tostring(result))
    end

    if type(originalRef) ~= "function" then
        error("hookfunction did not return the original function reference")
    end


    local originalPrint = print
    local printHookCalled = false
    local oldPrint
    
    oldPrint = hookfunction(print, function(...)
        printHookCalled = true
        return oldPrint(...)
    end)

    print("UNC_Hook_Test")
    hookfunction(print, oldPrint) 

    if not printHookCalled then
        error("Failed to hook a C function (print)")
    end
end)

enqueueTest("debug.getupvalue", function()
    local upvalue1 = "hello"
    local upvalue2 = 42
    local function testFunc()
        print(upvalue1, upvalue2)
    end

    local success, val1 = pcall(debug.getupvalue, testFunc, 1)
    if not success then
        error("Function crashed: " .. tostring(val1))
    end

    if val1 ~= "hello" then
        error("Incorrect value for upvalue 1 (expected 'hello', got " .. tostring(val1) .. ")")
    end

    local val2 = debug.getupvalue(testFunc, 2)
    if val2 ~= 42 then
        error("Incorrect value for upvalue 2 (expected 42, got " .. tostring(val2) .. ")")
    end

    local outOfBounds = debug.getupvalue(testFunc, 3)
    if outOfBounds ~= nil then
        error("Should return nil for out of bounds index")
    end

    local successParam, _ = pcall(debug.getupvalue, "not_a_function", 1)
    if successParam then
        error("Should error when passing non-function")
    end
end)

enqueueTest("setreadonly", function()
    local t = {
        a = 1,
        b = 2
    }
    
    local success, err = pcall(setreadonly, t, true)
    if not success then
        error("Function crashed: " .. tostring(err))
    end
    
    if table.isreadonly then
        if not table.isreadonly(t) then
            error("Table was not set to read-only")
        end
    end
    
    local writeSuccess, writeErr = pcall(function()
        t.a = 100
    end)
    
    if writeSuccess then
        error("Table allowed writing while in read-only mode")
    end
    
    setreadonly(t, false)
    
    if table.isreadonly then
        if table.isreadonly(t) then
            error("Table was not set to read-write")
        end
    end
    
    local rewriteSuccess, _ = pcall(function()
        t.a = 200
    end)
    
    if not rewriteSuccess or t.a ~= 200 then
        error("Table failed to allow writing after being set to read-write")
    end
    
    local successParam, _ = pcall(setreadonly, "not_a_table", true)
    if successParam then
        error("Should error when passing non-table")
    end
end)

enqueueTest("getloadedmodules", function()
    local modules = getloadedmodules()
    
    if type(modules) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(modules) .. ")")
    end

    if #modules == 0 then
        warn("getloadedmodules returned an empty table")
    end

    local foundModule = false
    for _, module in ipairs(modules) do
        if typeof(module) == "Instance" and module:IsA("ModuleScript") then
            foundModule = true
            break
        end
    end

    if not foundModule and #modules > 0 then
        error("Table contains objects that are not ModuleScripts")
    end


    local testModule = Instance.new("ModuleScript")
    testModule.Name = "UNC_LoadedModule_Test"
    testModule.Parent = game:GetService("RobloxReplicatedStorage")
    

    local s, e = pcall(require, testModule)
    
    local updatedModules = getloadedmodules()
    local isLoaded = false
    for _, module in ipairs(updatedModules) do
        if module == testModule then
            isLoaded = true
            break
        end
    end
    
    testModule:Destroy()
end)

enqueueTest("debug.getinfo", function()
    local function testFunc(a, b, c)
        return a + b + c
    end

    local info = debug.getinfo(testFunc)
    
    if type(info) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(info) .. ")")
    end

    if info.func ~= testFunc then
        error("Field 'func' does not match the target function")
    end

    if type(info.source) ~= "string" then
        error("Field 'source' is missing or invalid")
    end

    if info.numparams ~= 3 then
        error("Field 'numparams' incorrect (expected 3, got " .. tostring(info.numparams) .. ")")
    end

    local infoShort = debug.getinfo(testFunc, "s")
    if infoShort.numparams ~= nil then
    end

    local levelInfo = debug.getinfo(1)
    if type(levelInfo) ~= "table" or levelInfo.func == nil then
        error("Failed to retrieve info via stack level")
    end

    local success, _ = pcall(debug.getinfo, "not_a_function")
    if success then
        error("Should error when passing invalid argument")
    end
end)

enqueueTest("fireproximityprompt", function()
    local prompt = Instance.new("ProximityPrompt")
    local triggered = false
    
    prompt.Triggered:Connect(function()
        triggered = true
    end)
    
    local success, err = pcall(fireproximityprompt, prompt)
    
    if not success then
        error("Function crashed: " .. tostring(err))
    end
    
    task.wait(0.1)
    
    if not triggered then
        error("ProximityPrompt was not triggered")
    end
    
    local successParam, _ = pcall(fireproximityprompt, Instance.new("Part"))
    if successParam then
        error("Should error when passing non-ProximityPrompt")
    end
    
    prompt:Destroy()
end)

enqueueTest("WebSocket.connect", function()
    local socket, err = WebSocket.connect("ws://echo.websocket.events")
    
    if not socket then
        error("Failed to connect: " .. tostring(err))
    end
    
    if type(socket) ~= "table" and typeof(socket) ~= "UserData" then
        error("Socket object is not a table/userdata")
    end
    
    local testMessage = "UNC_WebSocket_Test"
    local received = false
    local responseData = ""
    
    socket.OnMessage:Connect(function(msg)
        responseData = msg
        received = true
    end)
    
    socket:Send(testMessage)
    
    local start = tick()
    while not received and tick() - start < 5 do
        task.wait(0.1)
    end
    
    if not received then
        error("Timed out waiting for OnMessage")
    end
    
    if responseData ~= testMessage then
        error("Message mismatch (expected '" .. testMessage .. "', got '" .. responseData .. "')")
    end
    
    if type(socket.Close) ~= "function" then
        error("Socket object missing Close method")
    end
    
    socket:Close()
    
    local success, _ = pcall(WebSocket.connect, "invalid_url")
    if success then
        error("Should fail when connecting to an invalid URL")
    end
end)

enqueueTest("listfiles", function()
    local folderName = "unc_test_folder_" .. tostring(math.random(1e5))
    makefolder(folderName)
    writefile(folderName .. "/test1.txt", "file1")
    writefile(folderName .. "/test2.txt", "file2")

    local files = listfiles(folderName)

    if type(files) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(files) .. ")")
    end

    if #files ~= 2 then
        error("Incorrect number of files (expected 2, got " .. #files .. ")")
    end

    local found1 = false
    local found2 = false
    for _, path in ipairs(files) do
        if path:find("test1.txt") then found1 = true end
        if path:find("test2.txt") then found2 = true end
    end

    if not (found1 and found2) then
        error("File paths not found in the returned table")
    end

    local rootFiles = listfiles("")
    if type(rootFiles) ~= "table" then
        error("Failed to list files in root directory")
    end

    local success, _ = pcall(listfiles, "non_existent_folder_99999")
    if success and #listfiles("non_existent_folder_99999") > 0 then
        error("Should not return files for a non-existent folder")
    end

    delfile(folderName .. "/test1.txt")
    delfile(folderName .. "/test2.txt")
    delfolder(folderName)
end)

enqueueTest("gethui", function()
    local hui = gethui()
    
    if typeof(hui) ~= "Instance" then
        error("Return type mismatch (expected Instance, got " .. typeof(hui) .. ")")
    end

    if hui.ClassName ~= "ScreenGui" and hui.ClassName ~= "Folder" and hui.ClassName ~= "CoreGui" then
        error("Unexpected class for Hidden UI container: " .. hui.ClassName)
    end

    local testPart = Instance.new("Frame")
    testPart.Name = "UNC_HUI_Test"
    testPart.Parent = hui

    local found = false
    for _, child in ipairs(hui:GetChildren()) do
        if child == testPart then
            found = true
            break
        end
    end

    if not found then
        error("Failed to parent and find object in Hidden UI container")
    end


    local coreGui = game:GetService("CoreGui")
    local detectableInCore = false
    for _, child in ipairs(coreGui:GetChildren()) do
        if child == testPart then
            detectableInCore = true
            break
        end
    end

    testPart:Destroy()
end)

enqueueTest("isreadonly", function()
    local t = {1, 2, 3}
    
    local initial = isreadonly(t)
    if type(initial) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(initial) .. ")")
    end

    setreadonly(t, true)
    if not isreadonly(t) then
        error("Failed to detect read-only state after setreadonly(t, true)")
    end

    setreadonly(t, false)
    if isreadonly(t) then
        error("Failed to detect read-write state after setreadonly(t, false)")
    end
    local success, _ = pcall(isreadonly, "string")
    if success then
        error("Should error when passing non-table")
    end
    if not isreadonly(math) and not isreadonly(string) then
        warn("Standard libraries (math/string) are not reported as read-only")
    end
end)

enqueueTest("getrenderproperty", function()
    local part = Instance.new("Part")
    part.Parent = workspace
    
    local success, value = pcall(getrenderproperty, part, "Color")
    if not success then
        error("Function crashed: " .. tostring(value))
    end

    if typeof(value) ~= "Color3" then
        error("Return type mismatch (expected Color3, got " .. typeof(value) .. ")")
    end

    local transparency = getrenderproperty(part, "Transparency")
    if type(transparency) ~= "number" then
        error("Return type mismatch (expected number, got " .. type(transparency) .. ")")
    end

    if transparency ~= part.Transparency then
        error("Value mismatch between render property and instance property")
    end

    local successParam, _ = pcall(getrenderproperty, part, "NonExistentProperty")
    if successParam then
        error("Should error when passing invalid property name")
    end

    local successInstance, _ = pcall(getrenderproperty, "not_an_instance", "Color")
    if successInstance then
        error("Should error when passing non-Instance")
    end

    part:Destroy()
end)

enqueueTest("lz4decompress", function()
    local data = "Hello World! This is a test for LZ4 decompression."
    local compressed = lz4compress(data)
    
    if type(compressed) ~= "string" then
        error("LZ4 compression failed to produce a string for test")
    end

    local decompressed = lz4decompress(compressed, #data)
    
    if type(decompressed) ~= "string" then
        error("Return type mismatch (expected string, got " .. type(decompressed) .. ")")
    end

    if decompressed ~= data then
        error("Decompression mismatch (expected '" .. data .. "', got '" .. decompressed .. "')")
    end

    local successSize, _ = pcall(lz4decompress, compressed, #data - 1)
    if successSize and _ == data then
        error("Should not return full data if size hint is too small")
    end

    local successData, _ = pcall(lz4decompress, "invalid_data", 10)
    if successData then
        error("Should error when passing invalid compressed data")
    end
end)

enqueueTest("appendfile", function()
    local fileName = "unc_append_test_" .. tostring(math.random(1e5)) .. ".txt"
    local initialData = "Hello"
    local appendedData = " World!"
    local expected = "Hello World!"

    writefile(fileName, initialData)

    local success, err = pcall(appendfile, fileName, appendedData)
    if not success then
        error("Function crashed: " .. tostring(err))
    end

    local content = readfile(fileName)
    if content ~= expected then
        error("Append mismatch (expected '" .. expected .. "', got '" .. content .. "')")
    end

    local successNew, _ = pcall(appendfile, "new_file_" .. fileName, "data")
    if not successNew then
        error("appendfile should create the file if it does not exist")
    end
    
    local contentNew = readfile("new_file_" .. fileName)
    if contentNew ~= "data" then
        error("New file content mismatch")
    end

    delfile(fileName)
    delfile("new_file_" .. fileName)
    
    local successParam, _ = pcall(appendfile, fileName, 12345)
    if successParam then
        error("Should error when passing non-string data")
    end
end)

enqueueTest("loadfile", function()
    local fileName = "unc_loadfile_test_" .. tostring(math.random(1e5)) .. ".lua"
    local code = "return 5 + 10"
    
    writefile(fileName, code)

    local success, result = pcall(loadfile, fileName)
    if not success then
        error("Function crashed: " .. tostring(result))
    end

    if type(result) ~= "function" then
        error("Return type mismatch (expected function, got " .. type(result) .. ")")
    end

    local callSuccess, finalValue = pcall(result)
    if not callSuccess or finalValue ~= 15 then
        error("Loaded function failed to execute correctly (expected 15, got " .. tostring(finalValue) .. ")")
    end

    local invalidCode = "return 5 + "
    writefile(fileName, invalidCode)
    
    local successInvalid, err = loadfile(fileName)
    if successInvalid then
        error("Should return nil/error when loading file with syntax errors")
    end

    local successNonExistent, _ = pcall(loadfile, "non_existent_file_999.lua")
    if successNonExistent and loadfile("non_existent_file_999.lua") ~= nil then
        error("Should return nil/error for non-existent files")
    end

    delfile(fileName)
end)

enqueueTest("getinstances", function()
    local instances = getinstances()
    
    if type(instances) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(instances) .. ")")
    end

    if #instances == 0 then
        error("getinstances returned an empty table")
    end

    local part = Instance.new("Part")
    local found = false
    
    local updatedInstances = getinstances()
    for _, obj in ipairs(updatedInstances) do
        if obj == part then
            found = true
            break
        end
    end

    if not found then
        error("Newly created instance not found in getinstances table")
    end

    local containsNonInstance = false
    for i = 1, math.min(#updatedInstances, 500) do
        if typeof(updatedInstances[i]) ~= "Instance" then
            containsNonInstance = true
            break
        end
    end

    if containsNonInstance then
        error("Table contains non-instance objects")
    end

    part:Destroy()
end)

enqueueTest("isexecutorclosure", function()
    local executorFunc = function() return true end
    local robloxFunc = print
    local hookFunc = function() return "hooked" end

    local isExec = isexecutorclosure(executorFunc)
    if type(isExec) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(isExec) .. ")")
    end

    if not isexecutorclosure(executorFunc) then
        error("Failed to identify an executor function")
    end

    if isexecutorclosure(robloxFunc) then
        error("Incorrectly identified a Roblox C function (print) as an executor closure")
    end

    local function nested()
        return function() end
    end
    if not isexecutorclosure(nested()) then
        error("Failed to identify a nested executor function")
    end

    if iscclosure and not iscclosure(robloxFunc) then
    end

    local success, _ = pcall(isexecutorclosure, "not_a_function")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("getcallbackvalue", function()
    local bindable = Instance.new("BindableFunction")
    local function testCallback() return "success" end
    
    bindable.OnInvoke = testCallback

    local success, value = pcall(getcallbackvalue, bindable, "OnInvoke")
    
    if not success then
        error("Function crashed: " .. tostring(value))
    end

    if type(value) ~= "function" then
        error("Return type mismatch (expected function, got " .. type(value) .. ")")
    end

    if value ~= testCallback then
        error("Value mismatch (the retrieved function does not match the assigned callback)")
    end

    local remote = Instance.new("RemoteFunction")
    local function remoteCallback() return true end
    remote.OnServerInvoke = remoteCallback

    local remoteValue = getcallbackvalue(remote, "OnServerInvoke")
    if remoteValue ~= remoteCallback then
        error("Failed to retrieve callback from RemoteFunction")
    end

    local successParam, _ = pcall(getcallbackvalue, bindable, "NonExistentCallback")
    if successParam and getcallbackvalue(bindable, "NonExistentCallback") ~= nil then
        error("Should return nil or error for non-existent callback properties")
    end

    bindable:Destroy()
    remote:Destroy()
end)

enqueueTest("getfunctionhash", function()
    local function testFunc()
        return "hello world"
    end
    
    local function testFuncDuplicate()
        return "hello world"
    end

    local hash = getfunctionhash(testFunc)
    
    if type(hash) ~= "string" then
        error("Return type mismatch (expected string, got " .. type(hash) .. ")")
    end

    if #hash == 0 then
        error("Returned hash is empty")
    end

    local hash2 = getfunctionhash(testFunc)
    if hash ~= hash2 then
        error("Hash is not deterministic for the same function")
    end

    local hash3 = getfunctionhash(testFuncDuplicate)

    if hash ~= hash3 then
        warn("Identical functions produced different hashes (implementation dependent)")
    end

    local success, _ = pcall(getfunctionhash, "not_a_function")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("replicatesignal", function()
    local part = Instance.new("Part")
    local signal = part:GetPropertyChangedSignal("Transparency")
    local fired = false
    
    signal:Connect(function()
        fired = true
    end)
    
    local success, err = pcall(replicatesignal, signal)
    
    if not success then
        error("Function crashed: " .. tostring(err))
    end
    
    task.wait(0.1)
    
    if not fired then
        error("Signal was not replicated/fired")
    end
    
    local remote = Instance.new("RemoteEvent")
    local remoteFired = false
    remote.OnClientEvent:Connect(function()
        remoteFired = true
    end)
    
    replicatesignal(remote.OnClientEvent)
    task.wait(0.1)
    
    if not remoteFired then
        error("Failed to replicate RemoteEvent signal")
    end
    
    local successParam, _ = pcall(replicatesignal, "not_a_signal")
    if successParam then
        error("Should error when passing invalid signal")
    end
    
    part:Destroy()
    remote:Destroy()
end)

enqueueTest("cleardrawcache", function()
    if not Drawing then
        error("Drawing library not available")
    end

    local line = Drawing.new("Line")
    line.Visible = true
    line.From = Vector2.new(0, 0)
    line.To = Vector2.new(100, 100)

    local success, err = pcall(cleardrawcache)
    
    if not success then
        error("Function crashed: " .. tostring(err))
    end

    local writeSuccess, _ = pcall(function()
        line.Color = Color3.new(1, 0, 0)
    end)

    if writeSuccess then
    end

    local newLine = Drawing.new("Square")
    if not newLine then
        error("Failed to create new Drawing object after clearing cache")
    end
    
    newLine:Remove()
end)

enqueueTest("filtergc", function()
    local testTable = {type = "UNC_FilterGC_Test", id = math.random(1e5)}
    local testFunc = function() return "UNC_FilterGC_Test_Func" end

    local tables = filtergc("table", {type = "UNC_FilterGC_Test"})
    
    if type(tables) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(tables) .. ")")
    end

    local found = false
    for _, t in ipairs(tables) do
        if type(t) == "table" and t.type == "UNC_FilterGC_Test" and t.id == testTable.id then
            found = true
            break
        end
    end

    if not found then
        error("Failed to find specific table using filtergc")
    end

    local functions = filtergc("function", function(f)
        local success, res = pcall(f)
        return success and res == "UNC_FilterGC_Test_Func"
    end)

    local foundFunc = false
    for _, f in ipairs(functions) do
        if f == testFunc then
            foundFunc = true
            break
        end
    end

    if not foundFunc then
        error("Failed to find specific function using predicate")
    end

    local successParam, _ = pcall(filtergc, "invalid_type", {})
    if successParam then
        error("Should error when passing invalid GC type")
    end
end)

enqueueTest("identifyexecutor", function()
    local name, version = identifyexecutor()
    
    if type(name) ~= "string" then
        error("Return type mismatch (expected string for name, got " .. type(name) .. ")")
    end

    if version ~= nil and type(version) ~= "string" then
        error("Return type mismatch (expected string or nil for version, got " .. type(version) .. ")")
    end

    if #name == 0 then
        error("Executor name is an empty string")
    end

    local name2, version2 = identifyexecutor()
    if name ~= name2 or version ~= version2 then
        error("identifyexecutor is not deterministic")
    end

    if getexecutorname then
        local gName, gVer = getexecutorname()
        if gName ~= name then
            error("identifyexecutor and getexecutorname return different names")
        end
    end
end)

enqueueTest("getscripthash", function()
    local script = Instance.new("LocalScript")
    script.Source = "print('UNC Test')"
    
    local hash = getscripthash(script)
    
    if type(hash) ~= "string" then
        error("Return type mismatch (expected string, got " .. type(hash) .. ")")
    end

    if #hash == 0 then
        error("Returned hash is empty")
    end

    local hash2 = getscripthash(script)
    if hash ~= hash2 then
        error("Hash is not deterministic for the same script source")
    end

    script.Source = "print('UNC Test Updated')"
    local hash3 = getscripthash(script)
    if hash == hash3 then
        error("Hash did not change after source modification")
    end

    local success, _ = pcall(getscripthash, "not_a_script")
    if success then
        error("Should error when passing non-Instance")
    end

    script:Destroy()
end)

enqueueTest("firesignal", function()
    local part = Instance.new("Part")
    local signal = part:GetPropertyChangedSignal("Name")
    local fired = false
    local passedArg = nil

    signal:Connect(function(arg)
        fired = true
        passedArg = arg
    end)

    local success, err = pcall(firesignal, signal, "TestArg")
    
    if not success then
        error("Function crashed: " .. tostring(err))
    end

    task.wait(0.1)

    if not fired then
        error("Signal was not fired")
    end

    local bindable = Instance.new("BindableEvent")
    local bindableFired = false
    local bindableArg = nil

    bindable.Event:Connect(function(arg)
        bindableFired = true
        bindableArg = arg
    end)

    firesignal(bindable.Event, "UNC_Data")
    task.wait(0.1)

    if not bindableFired then
        error("Failed to fire BindableEvent signal")
    end

    if bindableArg ~= "UNC_Data" then
    end

    local successParam, _ = pcall(firesignal, "not_a_signal")
    if successParam then
        error("Should error when passing invalid signal")
    end

    part:Destroy()
    bindable:Destroy()
end)

enqueueTest("firetouchinterest", function()
    local part = Instance.new("Part")
    part.Position = Vector3.new(0, 100, 0)
    part.CanTouch = true
    part.Parent = workspace

    local transmitter = Instance.new("Part")
    transmitter.Position = Vector3.new(0, 200, 0)
    transmitter.Parent = workspace

    local touched = false
    local connection = part.Touched:Connect(function(hit)
        if hit == transmitter then
            touched = true
        end
    end)

    local success, err = pcall(firetouchinterest, part, transmitter, 0)
    if not success then
        error("Function crashed on touch start: " .. tostring(err))
    end

    task.wait(0.1)

    if not touched then
        error("Touch event was not triggered")
    end

    local touchEnded = false
    local endConnection = part.TouchEnded:Connect(function(hit)
        if hit == transmitter then
            touchEnded = true
        end
    end)

    local successEnd, errEnd = pcall(firetouchinterest, part, transmitter, 1)
    if not successEnd then
        error("Function crashed on touch end: " .. tostring(errEnd))
    end

    task.wait(0.1)

    if not touchEnded then
        error("TouchEnded event was not triggered")
    end

    connection:Disconnect()
    endConnection:Disconnect()
    part:Destroy()
    transmitter:Destroy()

    local successParam, _ = pcall(firetouchinterest, workspace, "not_a_part", 0)
    if successParam then
        error("Should error when passing invalid arguments")
    end
end)

enqueueTest("debug.setstack", function()
    local function testFunc()
        local value = "original"
        local success, err = pcall(function()
            debug.setstack(2, 1, "modified")
        end)
        
        if not success then
            error("Function crashed: " .. tostring(err))
        end
        
        return value
    end

    local result = testFunc()
    
    if result ~= "modified" then
        error("Stack value was not modified (expected 'modified', got '" .. tostring(result) .. "')")
    end

    local function rangeTest()
        local a = 1
        local success, _ = pcall(debug.setstack, 1, 100, "oops")
        return success
    end

    if rangeTest() then
        error("Should error when setting stack index out of bounds")
    end

    local function typeTest()
        local success, _ = pcall(debug.setstack, 1, 1, 12345)
        return success
    end

    if not typeTest() then
        error("Failed to set stack with non-string value")
    end
end)

enqueueTest("isrenderobj", function()
    if not Drawing then
        error("Drawing library not available")
    end

    local line = Drawing.new("Line")
    
    local isObj = isrenderobj(line)
    if type(isObj) ~= "boolean" then
        error("Return type mismatch (expected boolean, got " .. type(isObj) .. ")")
    end

    if not isrenderobj(line) then
        error("Failed to identify a valid Drawing object")
    end

    local part = Instance.new("Part")
    if isrenderobj(part) then
        error("Incorrectly identified a Roblox Instance as a render object")
    end

    local tbl = {}
    if isrenderobj(tbl) then
        error("Incorrectly identified a table as a render object")
    end

    line:Remove()
    local success, result = pcall(isrenderobj, line)
    if success and result == true then
    end

    part:Destroy()
end)

enqueueTest("getcallingscript", function()
    local callingScript = getcallingscript()
    
    if callingScript ~= nil and typeof(callingScript) ~= "Instance" then
        error("Return type mismatch (expected Instance or nil, got " .. typeof(callingScript) .. ")")
    end

    local testPart = Instance.new("Part")
    local function check()
        return getcallingscript()
    end

    local result = check()
    if result ~= nil and not result:IsA("LuaSourceContainer") then
    end

    local script = Instance.new("LocalScript")
    script.Source = "getgenv().LastCallingScript = getcallingscript()"
    local success, _ = pcall(getcallingscript, "extra_arg")
    if not success then
    end
end)

enqueueTest("getcallingscript", function()
    local callingScript = getcallingscript()
    
    if callingScript ~= nil and typeof(callingScript) ~= "Instance" then
        error("Return type mismatch (expected Instance or nil, got " .. typeof(callingScript) .. ")")
    end

    local testPart = Instance.new("Part")
    local function check()
        return getcallingscript()
    end

    local result = check()
    if result ~= nil and not result:IsA("LuaSourceContainer") then
    end

    local script = Instance.new("LocalScript")
    script.Source = "getgenv().LastCallingScript = getcallingscript()"
    local success, _ = pcall(getcallingscript, "extra_arg")
    if not success then
    end
end)

enqueueTest("getsenv", function()
    local folder = game:GetService("ReplicatedStorage")
    local script = Instance.new("LocalScript")
    script.Name = "UNC_Getsenv_Test"
    script.Source = "shared.UNC_Value = 100"
    script.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")

    local success, env = pcall(getsenv, script)
    
    if not success then
        script:Destroy()
        error("Function crashed: " .. tostring(env))
    end

    if type(env) ~= "table" then
        script:Destroy()
        error("Return type mismatch (expected table, got " .. type(env) .. ")")
    end

    if env.script ~= script then
        script:Destroy()
        error("The 'script' variable in the environment does not match the target script")
    end

    local successParam, _ = pcall(getsenv, "not_a_script")
    if successParam then
        script:Destroy()
        error("Should error when passing non-script instance")
    end

    script:Destroy()
end)

enqueueTest("clonefunction", function()
    local function original(a, b)
        return a + b
    end
    
    local cloned = clonefunction(original)
    
    if type(cloned) ~= "function" then
        error("Return type mismatch (expected function, got " .. type(cloned) .. ")")
    end

    if cloned == original then
        error("Function was not cloned (returned the same reference)")
    end

    local result = cloned(10, 20)
    if result ~= 30 then
        error("Cloned function logic failure (expected 30, got " .. tostring(result) .. ")")
    end

    local function checkIsCloned()
        local infoOriginal = debug.getinfo(original)
        local infoCloned = debug.getinfo(cloned)
        
        if infoOriginal.short_src ~= infoCloned.short_src or infoOriginal.linedefined ~= infoCloned.linedefined then
            error("Cloned function metadata mismatch")
        end
    end
    
    checkIsCloned()

    local success, _ = pcall(clonefunction, "not_a_function")
    if success then
        error("Should error when passing non-function")
    end
end)

enqueueTest("debug.getconstant", function()
    local function testFunc()
        local a = "hello"
        local b = 123
        local c = print
        return a, b, c
    end

    local success, result = pcall(debug.getconstant, testFunc, 1)
    if not success then
        error("Function crashed: " .. tostring(result))
    end

    local constants = {}
    for i = 1, 10 do
        local val = debug.getconstant(testFunc, i)
        if val == nil then break end
        table.insert(constants, val)
    end

    local foundString = false
    local foundNumber = false

    for _, v in ipairs(constants) do
        if v == "hello" then foundString = true end
        if v == 123 then foundNumber = true end
    end

    if not foundString or not foundNumber then
        error("Could not find expected constants in function")
    end

    local successOut, _ = pcall(debug.getconstant, testFunc, 999)
    if successOut and debug.getconstant(testFunc, 999) ~= nil then
        error("Should return nil or error for out-of-bounds index")
    end

    local successParam, _ = pcall(debug.getconstant, "not_a_func", 1)
    if successParam then
        error("Should error when passing non-function")
    end
end)

enqueueTest("getgenv", function()
    local genv = getgenv()
    
    if type(genv) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(genv) .. ")")
    end

    local testKey = "UNC_Test_" .. tostring(math.random(1e5))
    genv[testKey] = true
    
    if _G[testKey] == true then
        warn("getgenv and _G share the same table (implementation dependent)")
    end

    if genv[testKey] ~= true then
        error("Failed to write/read from global environment")
    end

    local foundPrint = false
    if genv.print == print or genv.task == task then
        foundPrint = true
    end

    if not foundPrint then
    end

    local success, _ = pcall(function()
        genv[testKey] = nil
    end)
    
    if not success then
        error("Global environment is read-only")
    end
end)

enqueueTest("newcclosure", function()
    local function original(a, b)
        return a + b
    end
    
    local closure = newcclosure(original)
    
    if type(closure) ~= "function" then
        error("Return type mismatch (expected function, got " .. type(closure) .. ")")
    end

    if debug.getinfo(closure).what ~= "C" then
        error("The created closure is not identified as a C function")
    end

    local result = closure(5, 10)
    if result ~= 15 then
        error("Closure logic failure (expected 15, got " .. tostring(result) .. ")")
    end

    local success, err = pcall(function()
        local function nested()
            return debug.getinfo(2).name
        end
        local cNested = newcclosure(nested)
        cNested()
    end)
    
    if not success then
        error("CClosure crashed during execution: " .. tostring(err))
    end

    local successParam, _ = pcall(newcclosure, "not_a_function")
    if successParam then
        error("Should error when passing non-function")
    end
end)

enqueueTest("base64_decode", function()
    local input = "SGVsbG8gVU5D"
    local expected = "Hello UNC"
    
    local success, result = pcall(base64_decode, input)
    
    if not success then
        error("Function crashed: " .. tostring(result))
    end

    if type(result) ~= "string" then
        error("Return type mismatch (expected string, got " .. type(result) .. ")")
    end

    if result ~= expected then
        error("Decoding mismatch (expected '" .. expected .. "', got '" .. result .. "')")
    end

    local emptySuccess, emptyResult = pcall(base64_decode, "")
    if emptySuccess and emptyResult ~= "" then
        error("Failed to decode empty string correctly")
    end

    local paddingInput = "YWI=" -- "ab"
    if base64_decode(paddingInput) ~= "ab" then
        error("Failed to handle base64 padding correctly")
    end

    local invalidSuccess, _ = pcall(base64_decode, "!!!")
end)

enqueueTest("debug.getconstants", function()
    local function testFunc()
        local a = "UNC_Test_String"
        local b = 12345
        local c = 99.99
        print(a, b, c)
    end

    local success, constants = pcall(debug.getconstants, testFunc)
    
    if not success then
        error("Function crashed: " .. tostring(constants))
    end

    if type(constants) ~= "table" then
        error("Return type mismatch (expected table, got " .. type(constants) .. ")")
    end

    local foundString = false
    local foundInt = false
    local foundFloat = false

    for _, v in ipairs(constants) do
        if v == "UNC_Test_String" then foundString = true end
        if v == 12345 then foundInt = true end
        if v == 99.99 then foundFloat = true end
    end

    if not foundString then
        error("Failed to find string constant")
    end
    
    if not foundInt then
        error("Failed to find integer constant")
    end

    if not foundFloat then
    end

    local successParam, _ = pcall(debug.getconstants, "not_a_function")
    if successParam then
        error("Should error when passing non-function")
    end
end)

runTests()
