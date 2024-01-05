local cloneref = cloneref or function(...) return ... end
local Maid = getScript("libraries/Maid.lua")
local Signal = getScript("libraries/Signal.lua")

local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local Notifications = {}

local Notification = {}
Notification.__index = Notification
Notification.NotifGap = 40

local viewportSize = workspace.CurrentCamera.ViewportSize

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
local VALUE_NAMES = {
    number = "NumberValue",
    Color3 = "Color3Value",
    Vector2 = "Vector3Value",
}

local movingUpFinished = true
local movingDownFinished = true

function Notification.new(options)
    local self = setmetatable({
        _options = options
    }, Notification)

    self._options = options
    self._maid = Maid.new()

    self.Destroying = Signal.new()

	self._tweens = {}
    task.spawn(self._init, self)

    return self
end

function Notification:_createDrawingInstance(instanceType, properties)
    local instance = Drawing.new(instanceType)

    if properties.Visible == nil then
        properties.Visible = true
    end

    for i, v in next, properties do
        instance[i] = v
    end

    return instance
end

function Notification:_getTextBounds(text, fontSize)
    local t = Drawing.new("Text")
    t.Text = text
    t.Size = fontSize

    local res = t.TextBounds
    t:Remove()
    return res.X
end

function Notification:_tweenProperty(instance, property, value, tweenInfo, dontCancel)
    local currentValue = instance[property]
    local valueType = typeof(currentValue)
    local valueObject = Instance.new(VALUE_NAMES[valueType])

    self._maid:GiveTask(valueObject)
    if (valueType == "Vector2") then
        value = Vector3.new(value.X, value.Y, 0)
        currentValue = Vector3.new(currentValue.X, currentValue.Y, 0)
    end

    valueObject.Value = currentValue
    local tween = TweenService:Create(valueObject, tweenInfo, {Value = value})

	self._tweens[tween] = dontCancel or false

    self._maid:GiveTask(valueObject:GetPropertyChangedSignal("Value"):Connect(function()
        local newValue = valueObject.Value

        if (valueType == "Vector2") then
            newValue = Vector2.new(newValue.X, newValue.Y)
        end

		if self._destroyed then return end

        instance[property] = newValue
    end))

    self._maid:GiveTask(tween.Completed:Connect(function()
        valueObject:Destroy()
		self._tweens[tween] = nil
    end))

    tween:Play()

    if instance == self._progressBar and property == "Size" then
        self._maid:GiveTask(tween.Completed:Connect(function(playbackState)
            if (playbackState ~= Enum.PlaybackState.Completed) then return end
            self:Destroy()
        end))
    end

    return tween
end

function Notification:_init()
	self:MoveUp()

    local textSize = Vector2.new(self:_getTextBounds(self._options.text, 19), 30)
    textSize += Vector2.new(10, 0)

    self._textSize = textSize

    self._frame = self:_createDrawingInstance("Square", {
        Size = textSize,
        Position = viewportSize - Vector2.new(-10, textSize.Y+10),
        Color = Color3.fromRGB(12, 12, 12),
        Filled = true
    })

    self._originalPosition = self._frame.Position

    self._text = self:_createDrawingInstance("Text", {
        Text = self._options.text,
        Center = true,
        Color = Color3.fromRGB(255, 255, 255),
        Position = self._frame.Position + Vector2.new(textSize.X / 2, 5),
        Size = 19
    })

    self._progressBar = self:_createDrawingInstance("Square", {
        Size = Vector2.new(textSize.X, 3),
        Color = Color3.fromRGB(86, 180, 211),
        Filled = true,
        Position = self._frame.Position+Vector2.new(0, self._frame.Size.Y-3)
    })

	table.insert(Notifications,self)

    self._startTime = tick()
    local framePos = viewportSize - textSize - Vector2.new(10, 10)

    self:_tweenProperty(self._frame, "Position", framePos, TWEEN_INFO,true)
    self:_tweenProperty(self._text, "Position", framePos + Vector2.new(textSize.X/2, 5), TWEEN_INFO,true)
    local t = self:_tweenProperty(self._progressBar, "Position", framePos + Vector2.new(0, self._frame.Size.Y-3), TWEEN_INFO, true) --We dont really want this to be cancelable

	self._maid._progressConnection = t.Completed:Connect(function()
		if (self._options.duration) then
			self:_tweenProperty(self._progressBar, "Size", Vector2.new(0, 3), TweenInfo.new(self._options.duration, Enum.EasingStyle.Linear))
			self:_tweenProperty(self._progressBar, "Position", framePos - Vector2.new(-self._frame.Size.X, -(self._frame.Size.Y-3)), TweenInfo.new(self._options.duration, Enum.EasingStyle.Linear)) --You should technically remove this after its complete but doesn't matter
		end
	end)
end


function Notification:MouseInFrame()
	local mousePos = UserInputService:GetMouseLocation()
	local framePos = self._frame.Position
	local bottomRight = framePos + self._frame.Size

	return (mousePos.X >= framePos.X and mousePos.X <= bottomRight.X) and (mousePos.Y >= framePos.Y and mousePos.Y <= bottomRight.Y)
end

function Notification:GetHovered()
	for _,notif in next, Notifications do
		if notif:MouseInFrame() then return notif end
	end

	return
end

function Notification:MoveUp()

	if (self._destroyed) then return end

	repeat task.wait() until movingUpFinished

	movingUpFinished = false

	local distanceUp = Vector2.new(0, -self.NotifGap)

	for i,v in next, Notifications do
		v:CancelTweens()

		local newFramePos = v._frame.Position+distanceUp

		v._frame.Position = newFramePos
		v._text.Position = v._text.Position+distanceUp
		v._progressBar.Position = v._progressBar.Position+distanceUp

        if (not v._options.duration) then continue end

		local newDuration = v._options.duration-(tick()-v._startTime)

		v:_tweenProperty(v._progressBar, "Size", Vector2.new(0, 3), TweenInfo.new(newDuration, Enum.EasingStyle.Linear))
		v:_tweenProperty(v._progressBar, "Position", newFramePos - Vector2.new(-v._frame.Size.X, -(v._frame.Size.Y-3)), TweenInfo.new(newDuration, Enum.EasingStyle.Linear))
	end
	movingUpFinished = true
end


function Notification:MoveDown()

	if (self._destroyed) then return end

	repeat task.wait() until movingDownFinished

	movingDownFinished = false

	local distanceDown = Vector2.new(0, self.NotifGap)

	local index = table.find(Notifications,self) or 1

	for i = index, 1,-1 do
		local v = Notifications[i]

		v:CancelTweens()

		local newFramePos = v._frame.Position+distanceDown

		v._frame.Position = newFramePos
		v._text.Position = v._text.Position+distanceDown
		v._progressBar.Position = v._progressBar.Position+distanceDown

        if (not v._options.duration) then continue end

		v._startTime = v._startTime or tick()
		local newDuration = v._options.duration-(tick()-v._startTime)

		v:_tweenProperty(v._progressBar, "Size", Vector2.new(0, 3), TweenInfo.new(newDuration, Enum.EasingStyle.Linear))
		v:_tweenProperty(v._progressBar, "Position", newFramePos - Vector2.new(-v._frame.Size.X, -(v._frame.Size.Y-3)), TweenInfo.new(newDuration, Enum.EasingStyle.Linear))
	end
	movingDownFinished = true
end

function Notification:CancelTweens()
	for tween,cancelInfo in next, self._tweens do
		if cancelInfo then
			self._maid._progressConnection = nil
			tween.Completed:Wait()
			continue
		end
		tween:Cancel()
	end
end

function Notification:ClearAllAbove()
	local index = table.find(Notifications,self)

	for i = 1, index do
		task.spawn(function()
			Notifications[i]:Destroy()
		end)
	end
end

function Notification:Remove()
	table.remove(Notifications,table.find(Notifications,self))
end

function Notification:Destroy()
    if (self._destroyFixed) then return end
    self._destroyFixed = true

    self.Destroying:Fire()

    local framePos = self._originalPosition
    local textSize = self._textSize

	self:CancelTweens()

    self:_tweenProperty(self._frame, "Position", framePos, TWEEN_INFO,true)
    self:_tweenProperty(self._text, "Position", framePos + Vector2.new(textSize.X/2, 5), TWEEN_INFO,true)
    self:_tweenProperty(self._progressBar, "Position", framePos + Vector2.new(0, self._frame.Size.Y-3), TWEEN_INFO,true).Completed:Wait()

	self:MoveDown()

	self:Remove()

    self._destroyed = true

    self._frame:Remove()
	self._text:Remove()
	self._progressBar:Remove()
end

local function onInputBegan(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local notif = Notification:GetHovered()
		if notif then
			notif:Destroy()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		local notif = Notification:GetHovered()
		if notif then
			notif:ClearAllAbove()
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegan)

return Notification