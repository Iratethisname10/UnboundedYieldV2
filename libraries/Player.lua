-- orniginal script by 7GrandDadPGN
-- https://github.com/7GrandDadPGN/VapeV4ForRoblox/blob/main/Libraries/entityHandler.lua
-- edited by vocat

local controller = {
    playerList = {},
    playerConnections = {},
    playerCharConnections = {},
    playerIds = {},
    isAlive = false,
	LocalPosition = Vector3.zero
	allParts = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm", "LeftFoot", "LeftLowerLeg", "UpperTorso", "LeftUpperLeg", "RightFoot", "RightLowerLeg", "LowerTorso", "RightUpperLeg"}
    character = {
        Head = {},
        Humanoid = {},
        HumanoidRootPart = {}
    }
}

local cloneref = cloneref or function(...)
    return ...
end

local players = cloneref(game:GetService("Players"))
local httpservice = cloneref(game:GetService("HttpService"))

if not players.LocalPlayer then players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
local lplr = cloneref(players.LocalPlayer)

local playeradded = cloneref(Instance.new("BindableEvent"))
local playerremoved = cloneref(Instance.new("BindableEvent"))
local playerupdated = cloneref(Instance.new("BindableEvent"))

do
    controller.playerAddedEvent = {
        Connect = function(self, func)
            return playeradded.Event:Connect(func)
        end,
        connect = function(self, func)
            return playeradded.Event:Connect(func)
        end,
        Fire = function(self, ...)
            playeradded:Fire(...)
        end,
    }
    controller.playerRemovedEvent = {
        Connect = function(self, func)
            return playerremoved.Event:Connect(func)
        end,
        connect = function(self, func)
            return playerremoved.Event:Connect(func)
        end,
        Fire = function(self, ...)
            playerremoved:Fire(...)
        end,
    }
    controller.playerUpdatedEvent = {
        Connect = function(self, func)
            return playerupdated.Event:Connect(func)
        end,
        connect = function(self, func)
            return playerupdated.Event:Connect(func)
        end,
        Fire = function(self, ...)
            playerupdated:Fire(...)
        end,
    }

    controller.isPlayerTargetable = function(plr)
        if (not lplr.Team) then return true end
        if (not plr.Team) then return true end
        if plr.Team ~= lplr.Team then return true end
        return #plr.Team:GetPlayers() == #players:GetPlayers()
    end

    controller.getPlayerFromList = function(char, onlyPlayer)
        for i,v in next, controller.playerList do
            if v.Player == char then
				return onlyPlayer and v or i, v
            end
        end
    end

    controller.removePlayer = function(obj)
        local tableIndex, plr = controller.getPlayerFromList(obj)
        if tableIndex then
            controller.playerRemovedEvent:Fire(obj)
            if plr.Connections then
                for i,v in next, plr.Connections do 
                    if v.Disconnect then pcall(function() v:Disconnect() end) continue end
                    if v.disconnect then pcall(function() v:disconnect() end) continue end
                end
            end
            controller.playerList[tableIndex] = nil
        end
    end

    controller.refreshPlayer = function(plr, localcheck)
        controller.removePlayer(plr)
        controller.characterAdded(plr, plr.Character, localcheck, true)
    end

    controller.getUpdateConnections = function(plr)
        local hum = plr.Humanoid
        return {
            hum:GetPropertyChangedSignal("Health"),
            hum:GetPropertyChangedSignal("MaxHealth")
        }
    end

    controller.characterAdded = function(plr, char, localcheck, refresh)
        local id = httpservice:GenerateGUID(true)
        controller.playerIds[plr.Name] = id
        if char then
            task.spawn(function()
                local hum = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid", 10)
                local humrootpart = char:FindFirstChild("HumanoidRootPart") or hum and hum.RigType ~= Enum.HumanoidRigType.R6 and char.PrimaryPart
                if not humrootpart then
                    for i = 1, 500 do 
                        humrootpart = char:FindFirstChild("HumanoidRootPart") or hum and hum.RigType ~= Enum.HumanoidRigType.R6 and char.PrimaryPart
                        if humrootpart then break end
                        task.wait(0.01)
                    end
                end
                local head = char:WaitForChild("Head", 10) or humrootpart and setmetatable({Name = "Head", Size = Vector3.new(1, 1, 1), Parent = char}, {__index = function(t, k) 
                    if k == "Position" then
                        return humrootpart.Position + Vector3.new(0, 3, 0)
                    elseif k == "CFrame" then 
                        return humrootpart.CFrame + Vector3.new(0, 3, 0)
                    end
                end})
                if controller.playerIds[plr.Name] ~= id then return end
                if humrootpart and hum and head then
                    local childremoved
                    local newplr
                    if localcheck then
                        controller.isAlive = true
                        controller.character.Head = head
                        controller.character.Humanoid = hum
                        controller.character.HumanoidRootPart = humrootpart
                    else
                        newplr = {
                            Player = plr,
                            Character = char,
                            HumanoidRootPart = humrootpart,
                            RootPart = humrootpart,
                            Head = head,
                            Humanoid = hum,
                            Targetable = controller.isPlayerTargetable(plr),
                            Team = plr.Team,
                            Connections = {}
                        }
                        for i, v in next, controller.getUpdateConnections(newplr) do 
                            table.insert(newplr.Connections, v:Connect(function() 
                                controller.playerUpdatedEvent:Fire(newplr)
                            end))
                        end
                        table.insert(controller.playerList, newplr)
                        controller.playerAddedEvent:Fire(newplr)
                    end
                    childremoved = char.ChildRemoved:Connect(function(part)
                        if part == humrootpart or part == hum or part == head then
                            childremoved:Disconnect()
                            if localcheck then
                                controller.isAlive = false
                            else
                                controller.removePlayer(plr)
                            end
                        end
                    end)
                    if newplr then 
                        table.insert(newplr.Connections, childremoved)
                    end
                    table.insert(controller.playerConnections, childremoved)
                end
            end)
        end
    end

    controller.plrAdded = function(plr, localcheck, custom)
        table.insert(controller.playerConnections, plr:GetPropertyChangedSignal("Character"):Connect(function()
            if plr.Character then
                controller.refreshPlayer(plr, localcheck)
            else
                if localcheck then
                    controller.isAlive = false
                else
                    controller.removePlayer(plr)
                end
            end
        end))
        table.insert(controller.playerConnections, plr:GetPropertyChangedSignal("Team"):Connect(function()
            for i = 1, #controller.playerList do
                local v = controller.playerList[i]
                if v and v.Targetable ~= controller.isPlayerTargetable(v.Player) then 
                    controller.refreshPlayer(v.Player)
                end
            end 
            if localcheck then
                controller.fullRefresh()
            else
                controller.refreshPlayer(plr, localcheck)
            end
        end))
        if plr.Character then
            task.spawn(controller.refreshPlayer, plr, localcheck)
        end
    end

    controller.fullRefresh = function()
        controller.selfDestruct()
        for i,v in next, controller.playerIds do controller.playerIds[i] = nil end
        for i,v in next, players:GetPlayers() do controller.plrAdded(v, v == lplr) end
        table.insert(controller.playerConnections, players.PlayerAdded:Connect(function(v) controller.plrAdded(v, v == lplr) end))
        table.insert(controller.playerConnections, players.PlayerRemoving:Connect(function(v) controller.removePlayer(v) end))
    end

    controller.selfDestruct = function()
        for i,v in next, controller.playerConnections do 
            if v.Disconnect then pcall(function() v:Disconnect() end) continue end
            if v.disconnect then pcall(function() v:disconnect() end) continue end
        end
        for i,v in next, controller.playerIds do controller.playerIds[i] = nil end
        for i,v in next, controller.playerList do controller.removePlayer(v.Player) end
    end
end

return controller