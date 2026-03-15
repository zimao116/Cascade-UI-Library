local httpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local SaveManager = {}

SaveManager.Folder = "Zimao"
SaveManager.SubFolder = "User"
SaveManager.Ignore = {}
SaveManager.Options = {}

local function getFilePath()
    return SaveManager.Folder .. "/" .. SaveManager.SubFolder .. "/" .. localPlayer.Name .. ".json"
end

SaveManager.Parser = {
    Toggle = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                SaveManager.Options[idx].Value = value == true
            end
        end,
    },

    Slider = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                SaveManager.Options[idx].Value = tonumber(value)
            end
        end,
    },

    Stepper = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                SaveManager.Options[idx].Value = tonumber(value)
            end
        end,
    },

    TextField = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] and type(value) == "string" then
                SaveManager.Options[idx].Value = value

                task.defer(function()
                    local option = SaveManager.Options[idx]
                    if option and option.Structures then
                        option.Structures.Field.TextTruncate = Enum.TextTruncate.AtEnd
                        option.Structures.Body.AutomaticSize = Enum.AutomaticSize.None
                        option.Structures.Body.Size = UDim2.fromOffset(150, 23)
                    end
                end)
            end
        end,
    },

    KeybindField = {
        Save = function(idx, object)
            if object.Value and typeof(object.Value) == "EnumItem" then
                return object.Value.Name
            end
            return "Unknown"
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                local ok, keyCode = pcall(function()
                    return Enum.KeyCode[value]
                end)
                if ok and keyCode then
                    SaveManager.Options[idx].Value = keyCode
                end
            end
        end,
    },

    PullDownButton = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                SaveManager.Options[idx].Value = value
            end
        end,
    },

    PopUpButton = {
    Save = function(idx, object)
        local options = object.Options
        if options and object.Value then
            return options[object.Value]
        end
        return object.Value
    end,
    Load = function(idx, value)
        if SaveManager.Options[idx] then
            local options = SaveManager.Options[idx].Options
            if options and type(value) == "string" then
                for i, name in ipairs(options) do
                    if name == value then
                        SaveManager.Options[idx].Value = i
                        return
                    end
                end
                SaveManager.Options[idx].Value = 1
            else
                SaveManager.Options[idx].Value = value
            end
        end
    end,
},

    RadioButtonGroup = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                SaveManager.Options[idx].Value = value
            end
        end,
    },

    Table = {
        Save = function(idx, object)
            return object.Value
        end,
        Load = function(idx, value)
            if SaveManager.Options[idx] then
                if type(value) == "table" and type(SaveManager.Options[idx].Value) == "table" then
                    for k, v in next, value do
                        SaveManager.Options[idx].Value[k] = v
                    end
                else
                    SaveManager.Options[idx].Value = value
                end

                if SaveManager.Options[idx].OnChanged then
                    task.spawn(SaveManager.Options[idx].OnChanged, SaveManager.Options[idx].Value)
                end
            end
        end,
    },
}

function SaveManager:RegisterOption(idx, componentObject)
    self.Options[idx] = componentObject

    local originalChanged = componentObject.ValueChanged

    componentObject.ValueChanged = function(self, value)
        if originalChanged then
            originalChanged(self, value)
        end
        SaveManager:Save()
    end
end

function SaveManager:RegisterTable(idx, tableRef, onChanged)
    self.Options[idx] = {
        Type = "Table",
        Value = tableRef,
        OnChanged = function(newTable)
            if onChanged then
                onChanged(newTable)
            end
            SaveManager:Save()
        end,
    }
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in next, list do
        self.Ignore[key] = true
    end
end

function SaveManager:SetApp(app)
    self.App = app
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:BuildFolderTree()
    local paths = {
        self.Folder,
        self.Folder .. "/" .. self.SubFolder,
    }
    for _, path in ipairs(paths) do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

function SaveManager:Save()
    local dataSave = {}

    for idx, option in next, self.Options do
        if not self.Parser[option.Type] then continue end
        if self.Ignore[idx] then continue end
        dataSave[idx] = self.Parser[option.Type].Save(idx, option)
    end

    local data = { DataSave = dataSave }

    local success, encoded = pcall(httpService.JSONEncode, httpService, data)
    if not success then
        return false, "failed to encode data"
    end

    writefile(getFilePath(), encoded)
    return true
end

function SaveManager:Load()
    local file = getFilePath()
    if not isfile(file) then
        return false, "no save file found for " .. localPlayer.Name
    end

    local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
    if not success then
        return false, "decode error"
    end

    local dataSave = decoded.DataSave
    if type(dataSave) ~= "table" then
        return false, "invalid file format"
    end

    for idx, value in next, dataSave do
        local option = self.Options[idx]
        if not option then continue end
        if not self.Parser[option.Type] then continue end

        task.spawn(function()
            self.Parser[option.Type].Load(idx, value)
        end)
    end

    return true
end

function SaveManager:AutoLoad()
    self:Load()
end

function SaveManager:BuildConfigSection(tab)
    assert(self.App, "Must call SaveManager:SetApp(app) before BuildConfigSection")

    local form = tab:Form()

    local saveRow = form:Row({ SearchIndex = "Save settings" })
    saveRow:Left():TitleStack({
        Title = "Save settings",
        Subtitle = "File: " .. localPlayer.Name .. ".json",
    })
    saveRow:Right():Button({
        Label = "Save",
        State = "Primary",
        Pushed = function()
            self:Save()
        end,
    })

    local loadRow = form:Row({ SearchIndex = "Load settings" })
    loadRow:Left():TitleStack({
        Title = "Load settings",
        Subtitle = "File: " .. localPlayer.Name .. ".json",
    })
    loadRow:Right():Button({
        Label = "Load",
        State = "Secondary",
        Pushed = function()
            self:Load()
        end,
    })
end

SaveManager:BuildFolderTree()

return SaveManager
