---@diagnostic disable: undefined-global

local env = getgenv()

assert(type(env) == 'table', 'aim-assistant.lua: failed to get environment')
pcall(function() env.stop_aim_assistant() end)

local instances = {}
local connections = {}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

--- @type { new: function }
local instance = env.Instance
local Instance = {
    new = function(class, parent)
        local instance = instance.new(class, parent)
        table.insert(instances, instance)
        return instance
    end
}

local players = game:GetService("Players")
local got_ui, ui_source = pcall(function()
    return game:GetObjects("rbxassetid://11738969913")
end)

assert(got_ui, 'aim-assistant.lua: failed to get ui')

local coregui
if type(gethui) == 'function' then
    coregui = gethui()
else
    coregui = game:GetService("CoreGui")
end

local ui = ui_source[1]
ui.Enabled = true
ui.Parent = coregui
table.insert(instances, ui)

local esp = true
local ffa = true
local fov = 4
local sens = 0.2
local aimbot = true

local v2 = Vector2.new
local v3 = Vector3.new
local c3 = Color3.new
local c3u = Color3.fromRGB

local rbxclass = game.IsA
local rbxchild = game.FindFirstChild
local rbxchildwait = game.WaitForChild
local rbxclasschild = game.FindFirstChildWhichIsA
local rbxdescendant = game.IsDescendantOf

local ui_frame = ui:WaitForChild("MainFrame")
local ui_circle = ui:WaitForChild("Circle")
local ui_content = ui_frame:WaitForChild("Content")

local ui_aimcontroller = ui_content:WaitForChild("AimbotController")
local ui_espcontroller = ui_content:WaitForChild("ESPController")
local ui_ffacontroller = ui_content:WaitForChild("FFAController")
local ui_fovcontroller = ui_content:WaitForChild("FOVController")
local ui_sencontroller = ui_content:WaitForChild("SensitivityController")

local ui_topbar = ui_frame:WaitForChild("TopBar")
local ui_domainlabel = ui_frame:WaitForChild("DomainLabel")
local ui_versionlabel = ui_frame:WaitForChild("TextLabel")

ui_domainlabel.Text = 'shawnjbragdon'
ui_versionlabel.Text = '[2.1.0]'

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Blacklist
params.IgnoreWater = true

local function ray(origin, direction)
    return {
        origin = origin,
        direction = direction
    }
end

local function raycast(worldroot, rayobject, ignorelist)
    local origin, direction = rayobject.origin, rayobject.direction
    params.FilterDescendantsInstances = type(ignorelist) == 'table' and ignorelist or nil
    return worldroot:Raycast(origin, direction, params).Instance
end

local color_scheme = {}
color_scheme['nearest'] = c3u(0, 172, 255)
color_scheme['valid'] = c3u(38, 255, 99)
color_scheme['invalid'] = c3u(255, 37, 40)

local function spawn(f, ...)
    local args = { ... }
    local thread = coroutine.create(f)
    return coroutine.resume(thread, unpack(args))
end

local localplayer = players.LocalPlayer
local playermouse = localplayer:GetMouse()
local currentcamera = workspace.CurrentCamera

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    currentcamera = workspace.CurrentCamera
end)

local touch = Enum.UserInputType.Touch
local keycode = { f6 = Enum.KeyCode.F6 }
local mousebutton1 = Enum.UserInputType.MouseButton1
local mousebutton2 = Enum.UserInputType.MouseButton2
local mousemovement = Enum.UserInputType.MouseMovement
local mousebutton1down = false
local mousebutton2down = false

local userinputservice = game:GetService("UserInputService")
local inputbegan = userinputservice.InputBegan
local inputended = userinputservice.InputEnded
local inputchanged = userinputservice.InputChanged
local inputendstate = Enum.UserInputState.End
local inputbeginstate = Enum.UserInputState.Begin

spawn(function(dragging, dragInput, dragStart, startPos)
    local function update(input)
        local delta = input.Position - dragStart
        ui_frame.Position =
            UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    connect(ui_frame.InputBegan, function(input)
        if input.UserInputType == mousebutton1
            or input.UserInputType == touch
        then
            dragging = true
            dragStart = input.Position
            startPos = ui_frame.Position

            connect(input.Changed, function()
                if input.UserInputState == inputendstate then
                    dragging = false
                end
            end)
        end
    end)
    connect(ui_frame.InputChanged, function(input)
        if input.UserInputType == mousemovement
            or input.UserInputType == touch
        then
            dragInput = input
        end
    end)
    connect(uis.InputChanged, function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end)

connect(rbxchildwait(ui_fovcontroller, 'TextBox').FocusLost, function(enter_pressed)
    if enter_pressed then
        local input = ui_fovcontroller.TextBox.Text
        local number = tonumber(input)
        if type(number) == 'number' then
            fov = number
            ui_fovcontroller.TextBox.Text = input
        end
    end
end)

connect(rbxchildwait(ui_sencontroller, 'TextBox').FocusLost, function(enter_pressed)
    if enter_pressed then
        local input = ui_sencontroller.TextBox.Text
        local number = tonumber(input)
        if type(number) == 'number' then
            sens = number
            ui_sencontroller.TextBox.Text = input
        end
    end
end)

local function can_track(player, character)
    if typeof(player) == 'Instance' and player:IsA("Model") then
        character = player
        player = players:GetPlayerFromCharacter(character)
    end
    return player and player ~= localplayer and (ffa or player.Team ~= localplayer.Team)
end

local content = {}
local highlight = {}
highlight.__index = highlight

function highlight.new(player)
    if content[player] then
        return content[player]
    end
    local self = setmetatable({}, highlight)
    self.player = player
    local highlight = Instance.new("Highlight")
    highlight.Enabled = can_track(player)
    highlight.FillColor = color_scheme['invalid']
    highlight.OutlineColor = color_scheme['invalid']
    highlight.Parent = ui
    connect(player.CharacterAdded, function(character)
        self.character = character
        highlight.Adornee = character
        highlight.Enabled = can_track(player)
    end)
    if player.Character then
        self.character = player.Character
        highlight.Adornee = player.Character
        highlight.Enabled = can_track(player)
    end
    connect(player:GetPropertyChangedSignal("Team"), function()
        highlight.Enabled = can_track(player)
    end)
    self.highlight = highlight
    content[player] = self
    return self
end

function highlight:destroy()
    self.highlight:Destroy()
end

function highlight:valid()
    return can_track(self.player)
end

function highlight:color(color)
    self.highlight.FillColor = color
    self.highlight.OutlineColor = color
end

function highlight:enabled(enabled)
    self.highlight.Enabled = enabled
end

local function get_enemy_players()
    local enemy_players = {}
    for _, potential_enemy in pairs(players:GetPlayers()) do
        if potential_enemy ~= localplayer then
            local local_entry = content[potential_enemy]
            if not local_entry then
                highlight.new(potential_enemy)
                local_entry = content[potential_enemy]
            end
            local_entry:enabled(can_track(local_entry.player))
            if (ffa or potential_enemy.Team ~= localplayer.Team) then
                table.insert(enemy_players, potential_enemy)
            end
        end
    end
    return enemy_players
end

local function get_enemy_characters()
    local enemy_characters = {}
    for _, enemy_player in pairs(get_enemy_players()) do
        local enemy_character = enemy_player.Character
        local enemy_humanoid = typeof(enemy_character) == 'Instance' and rbxclasschild(enemy_character, 'Humanoid')
        if (enemy_humanoid and enemy_humanoid.Health > 0) or not enemy_humanoid then
            table.insert(enemy_characters, enemy_character)
        end
    end
    return enemy_characters
end

local function get_nearest_character(current_target)
    local nearest_character, nearest_screenpoint
    local closest_distance = 2048
    local camera_position = currentcamera.CFrame.Position
    for _, character in pairs(get_enemy_characters()) do
        local local_entry
        local local_color_selection = color_scheme['invalid']
        for _, entry in pairs(content) do
            if entry.character == character then
                local_entry = entry
                break
            end
        end
        local head = rbxchild(character, 'Head')
        if typeof(head) == 'Instance' and head:IsA('BasePart') then
            local screen_position, on_screen = currentcamera:WorldToScreenPoint(head.Position)
            local screen_distance = (v2(playermouse.X, playermouse.Y) - v2(screen_position.X, screen_position.Y))
            .Magnitude
            if on_screen then
                local_entry:enabled(can_track(local_entry.player))
                local hit = raycast(
                    workspace,
                    ray(camera_position, (head.Position - camera_position).Unit * 2048),
                    { currentcamera, localplayer.Character }
                )
                if typeof(hit) == 'Instance' and rbxdescendant(hit, character) then
                    if screen_distance < closest_distance and screen_distance <= currentcamera.ViewportSize.X / (90 / fov) then
                        nearest_character = character
                        nearest_screenpoint = screen_position
                        closest_distance = screen_distance
                        local_color_selection = color_scheme['valid']
                    end
                end
            else
                local_entry:enabled(false)
            end
        end
        if current_target ~= nearest_character then
            local_entry:color(local_color_selection)
        end
    end
    return nearest_character, nearest_screenpoint
end

connect(inputbegan, function(input)
    if userinputservice:GetFocusedTextBox() then
        return
    end
    if input.UserInputType == mousebutton1 then
        mousebutton1down = true
    elseif input.UserInputType == mousebutton2 then
        mousebutton2down = true
    end
end)

connect(inputended, function(input)
    if userinputservice:GetFocusedTextBox() then
        return
    end
    if input.UserInputType == mousebutton1 then
        mousebutton1down = false
    elseif input.UserInputType == mousebutton2 then
        mousebutton2down = false
    end
end)

local function load_player(player)
    if player ~= localplayer then
        highlight.new(player)
    end
end

for _, player in pairs(players:GetPlayers()) do
    load_player(player)
end

connect(players.PlayerAdded, load_player)
connect(players.PlayerRemoving, function(player)
    if player ~= localplayer then
        local entry = content[player]
        if entry then
            entry:destroy()
            content[player] = nil
        end
    end
end)

local function update_mouse()
    if currentcamera then
        local viewport_size = currentcamera.ViewportSize * 2
        local x, y = playermouse.X, playermouse.Y
        ui_circle.Position = UDim2.fromOffset(x, y)
        ui_circle.Size = UDim2.fromOffset(viewport_size.X / (90 / fov), viewport_size.X / (90 / fov))
    end
end

connect(playermouse.Move, update_mouse)
connect(userinputservice:GetPropertyChangedSignal("MouseBehavior"), update_mouse)

local current_target

local nearest_player
local nearest_character
local nearest_screenpoint

local last_time = 0
local frame_rate = 60
local frame_delta = 1 / frame_rate

--- Moves the mouse relative to its current position.
--- @type function
local mousemoverel = env.mousemoverel

connect(rbxchildwait(ui_ffacontroller, 'ImageButton').MouseButton1Up, function()
    ffa = not ffa
    ui_ffacontroller.ImageButton.TextLabel.Text = ffa and '✓' or ''
    for _, entry in pairs(content) do
        entry:enabled(can_track(entry.player))
    end
end)

connect(rbxchildwait(ui_espcontroller, 'ImageButton').MouseButton1Up, function()
    esp = not esp
    ui_espcontroller.ImageButton.TextLabel.Text = ffa and '✓' or ''
    for _, entry in pairs(content) do
        entry:enabled(can_track(entry.player))
    end
end)

connect(rbxchildwait(ui_aimcontroller, 'ImageButton').MouseButton1Up, function()
    aimbot = not aimbot
    ui_aimbotcontroller.ImageButton.TextLabel.Text = aimbot and '✓' or ''
    circle.Visible = aimbot
end)

connect(game:GetService("RunService").Stepped, function(time, delta_time)
    current_target = nearest_character
    nearest_character, nearest_screenpoint = get_nearest_character(current_target)
    if aimbot and (mousebutton1down or mousebutton2down) and nearest_character and nearest_screenpoint and
        (time > last_time + frame_delta or delta_time > frame_delta) then
        last_time = time
        nearest_player = players:GetPlayerFromCharacter(nearest_character)
        if nearest_player then
            content[nearest_player]:color(color_scheme['nearest'])
        end
        mousemoverel((nearest_screenpoint.X - playermouse.X) * sens, (nearest_screenpoint.Y - playermouse.Y) * sens)
        ui_circle.Position = UDim2.fromOffset(nearest_screenpoint.X, nearest_screenpoint.Y)
    end
end)

env.stop_aim_assistant = function()
    for _, connection in pairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, instance in pairs(instances) do
        pcall(function()
            instance:Destroy()
        end)
    end
    for _, entry in pairs(content) do
        pcall(function()
            entry:destroy()
        end)
    end
    content = nil
    connections = nil
    instances = nil
end
