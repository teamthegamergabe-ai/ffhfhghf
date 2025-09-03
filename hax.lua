local service = 5825;--Set your Platoboost Id 
local secret = "9009c13b-8ba0-4d10-b04e-cc07ff022983"; --Set Your Platoboost Api key
local useNonce = true; 
local onMessage = function(message)  game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = message; }) end;


repeat task.wait(1) until game:IsLoaded() or game.Players.LocalPlayer;


local requestSending = false;
local fSetClipboard, fRequest, fStringChar, fToString, fStringSub, fOsTime, fMathRandom, fMathFloor, fGetHwid = setclipboard or toclipboard, request or http_request, string.char, tostring, string.sub, os.time, math.random, math.floor, gethwid or function() return game:GetService("Players").LocalPlayer.UserId end
local cachedLink, cachedTime = "", 0;
local HttpService = game:GetService("HttpService")

function lEncode(data)
	return HttpService:JSONEncode(data)
end
function lDecode(data)
	return HttpService:JSONDecode(data)
end
local function lDigest(input)
	local inputStr = tostring(input)


	local hash = {}
	for i = 1, #inputStr do
		table.insert(hash, string.byte(inputStr, i))
	end

	local hashHex = ""
	for _, byte in ipairs(hash) do
		hashHex = hashHex .. string.format("%02x", byte)
	end

	return hashHex
end
local host = "https://api.platoboost.com";
local hostResponse = fRequest({
	Url = host .. "/public/connectivity",
	Method = "GET"
});
if hostResponse.StatusCode ~= 200 or hostResponse.StatusCode ~= 429 then
	host = "https://api.platoboost.net";
end

function cacheLink()
	if cachedTime + (10*60) < fOsTime() then
		local response = fRequest({
			Url = host .. "/public/start",
			Method = "POST",
			Body = lEncode({
				service = service,
				identifier = lDigest(fGetHwid())
			}),
			Headers = {
				["Content-Type"] = "application/json"
			}
		});

		if response.StatusCode == 200 then
			local decoded = lDecode(response.Body);

			if decoded.success == true then
				cachedLink = decoded.data.url;
				cachedTime = fOsTime();
				return true, cachedLink;
			else
				onMessage(decoded.message);
				return false, decoded.message;
			end
		elseif response.StatusCode == 429 then
			local msg = "you are being rate limited, please wait 20 seconds and try again.";
			onMessage(msg);
			return false, msg;
		end

		local msg = "Failed to cache link.";
		onMessage(msg);
		return false, msg;
	else
		return true, cachedLink;
	end
end



cacheLink();

local generateNonce = function()
	local str = ""
	for _ = 1, 16 do
		str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97)
	end
	return str
end


for _ = 1, 5 do
	local oNonce = generateNonce();
	task.wait(0.2)
	if generateNonce() == oNonce then
		local msg = "platoboost nonce error.";
		onMessage(msg);
		error(msg);
	end
end

local copyLink = function()
	local success, link = cacheLink();

	if success then
		print("SetClipBoard")
		fSetClipboard(link);
	end
end

local redeemKey = function(key)
	local nonce = generateNonce();
	local endpoint = host .. "/public/redeem/" .. fToString(service);

	local body = {
		identifier = lDigest(fGetHwid()),
		key = key
	}

	if useNonce then
		body.nonce = nonce;
	end

	local response = fRequest({
		Url = endpoint,
		Method = "POST",
		Body = lEncode(body),
		Headers = {
			["Content-Type"] = "application/json"
		}
	});

	if response.StatusCode == 200 then
		local decoded = lDecode(response.Body);
		if decoded.success == true then
			if decoded.data.valid == true then
				if useNonce then
					if decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
						return true;
					else
						onMessage("failed to verify integrity.");
						return false;
					end    
				else
					return true;
				end
			else
				onMessage("key is invalid.");
				return false;
			end
		else
			if fStringSub(decoded.message, 1, 27) == "unique constraint violation" then
				onMessage("you already have an active key, please wait for it to expire before redeeming it.");
				return false;
			else
				onMessage(decoded.message);
				return false;
			end
		end
	elseif response.StatusCode == 429 then
		onMessage("you are being rate limited, please wait 20 seconds and try again.");
		return false;
	else
		onMessage("server returned an invalid status code, please try again later.");
		return false; 
	end
end


local verifyKey = function(key)
	if requestSending == true then
		onMessage("a request is already being sent, please slow down.");
		return false;
	else
		requestSending = true;
	end

	local nonce = generateNonce();
	local endpoint = host .. "/public/whitelist/" .. fToString(service) .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key;

	if useNonce then
		endpoint = endpoint .. "&nonce=" .. nonce;
	end
	local response = fRequest({
		Url = endpoint,
		Method = "GET",
	});

	requestSending = false;

	if response.StatusCode == 200 then
		local decoded = lDecode(response.Body);
		if decoded.success == true then
			if decoded.data.valid == true then
				if useNonce then
					return true;
				else
					return true;
				end
			else
				if fStringSub(key, 1, 4) == "FREE_" then
					return redeemKey(key);
				else
					onMessage("key is invalid.");
					return false;
				end
			end
		else
			onMessage(decoded.message);
			return false;
		end
	elseif response.StatusCode == 429 then
		onMessage("you are being rate limited, please wait 20 seconds and try again.");
		return false;
	else
		onMessage("server returned an invalid status code, please try again later.");
		return false;
	end
end


local getFlag = function(name)
	local nonce = generateNonce();
	local endpoint = host .. "/public/flag/" .. fToString(service) .. "?name=" .. name;

	if useNonce then
		endpoint = endpoint .. "&nonce=" .. nonce;
	end

	local response = fRequest({
		Url = endpoint,
		Method = "GET",
	});

	if response.StatusCode == 200 then
		local decoded = lDecode(response.Body);
		if decoded.success == true then
			if useNonce then
				if decoded.data.hash == lDigest(fToString(decoded.data.value) .. "-" .. nonce .. "-" .. secret) then
					return decoded.data.value;
				else
					onMessage("failed to verify integrity.");
					return nil;
				end
			else
				return decoded.data.value;
			end
		else
			onMessage(decoded.message);
			return nil;
		end
	else
		return nil;
	end
end

if game.Players.LocalPlayer.UserId == 4918704472 then
	-- Gui to Lua
	-- Version: 3.2

	-- Instances:

	local AdminGuiPaid = Instance.new("ScreenGui")
	local AdminFrame = Instance.new("Frame")
	local Corner = Instance.new("UICorner")
	local Yes = Instance.new("TextButton")
	local Corner_2 = Instance.new("UICorner")
	local No = Instance.new("TextButton")
	local UICorner = Instance.new("UICorner")
	local TextAdmin = Instance.new("TextLabel")

	--Properties:

	AdminGuiPaid.Name = "AdminGui (Paid)"
	AdminGuiPaid.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	AdminGuiPaid.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	AdminFrame.Name = "AdminFrame"
	AdminFrame.Parent = AdminGuiPaid
	AdminFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	AdminFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	AdminFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	AdminFrame.BorderSizePixel = 0
	AdminFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	AdminFrame.Size = UDim2.new(0, 533, 0, 192)
	AdminFrame.ZIndex = 99999

	Corner.Name = "Corner"
	Corner.Parent = AdminFrame

	Yes.Name = "Yes"
	Yes.Parent = AdminFrame
	Yes.BackgroundColor3 = Color3.fromRGB(170, 255, 0)
	Yes.BorderColor3 = Color3.fromRGB(255, 255, 255)
	Yes.BorderSizePixel = 26
	Yes.Position = UDim2.new(0.101313323, 0, 0.661458313, 0)
	Yes.Size = UDim2.new(0, 124, 0, 50)
	Yes.Font = Enum.Font.Unknown
	Yes.Text = "Yes"
	Yes.TextColor3 = Color3.fromRGB(0, 0, 0)
	Yes.TextScaled = true
	Yes.TextSize = 14.000
	Yes.TextWrapped = true

	Corner_2.Name = "Corner"
	Corner_2.Parent = Yes

	No.Name = "No"
	No.Parent = AdminFrame
	No.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	No.BorderColor3 = Color3.fromRGB(255, 255, 255)
	No.BorderSizePixel = 26
	No.Position = UDim2.new(0.649155736, 0, 0.661458313, 0)
	No.Size = UDim2.new(0, 124, 0, 50)
	No.Font = Enum.Font.Unknown
	No.Text = "No"
	No.TextColor3 = Color3.fromRGB(0, 0, 0)
	No.TextScaled = true
	No.TextSize = 14.000
	No.TextWrapped = true

	UICorner.Parent = No

	TextAdmin.Parent = AdminFrame
	TextAdmin.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TextAdmin.BorderColor3 = Color3.fromRGB(255, 255, 255)
	TextAdmin.BorderSizePixel = 2
	TextAdmin.Position = UDim2.new(0.193245783, 0, 0.03125, 0)
	TextAdmin.Size = UDim2.new(0, 326, 0, 50)
	TextAdmin.Font = Enum.Font.Unknown
	TextAdmin.Text = "Do you want to load the script or do the key system (you can do this back in the corner)"
	TextAdmin.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextAdmin.TextScaled = true
	TextAdmin.TextSize = 14.000
	TextAdmin.TextWrapped = true
	
	for i = 20, -0.1 do
		if AdminGuiPaid.Enabled == true then
			task.wait(10)
			TextAdmin.Text = "Minimizing in " .. string.format("%.1f", i) .. "(you can open by pressing Admin in the top right corner)"
			task.wait(20)
			AdminGuiPaid.Enabled = false
		end
	end
	
	if AdminGuiPaid.Enabled == false then
		-- Gui to Lua
		-- Version: 3.2

		-- Instances:

		local Load = Instance.new("ScreenGui")
		local AdminButtton = Instance.new("TextButton")
		local UICorner = Instance.new("UICorner")

		--Properties:

		Load.Name = "Load"
		Load.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
		Load.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		AdminButtton.Name = "AdminButtton"
		AdminButtton.Parent = Load
		AdminButtton.AnchorPoint = Vector2.new(0.703999996, 0.0189999994)
		AdminButtton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		AdminButtton.BorderColor3 = Color3.fromRGB(0, 0, 0)
		AdminButtton.BorderSizePixel = 0
		AdminButtton.Position = UDim2.new(0.703871906, 0, 0.0192554556, 0)
		AdminButtton.Size = UDim2.new(0, 113, 0, 50)
		AdminButtton.Font = Enum.Font.FredokaOne
		AdminButtton.Text = "Admin"
		AdminButtton.TextColor3 = Color3.fromRGB(255, 255, 255)
		AdminButtton.TextScaled = true
		AdminButtton.TextSize = 14.000
		AdminButtton.TextTransparency = 0.500
		AdminButtton.TextWrapped = true

		UICorner.Parent = AdminButtton
		
		AdminButtton.MouseButton1Click:Connect(function()
			if AdminGuiPaid.Enabled == false then
				AdminGuiPaid.Enabled = true
			end
		end)
	end
	
	Yes.MouseButton1Click:Connect(function()
		if game.Players.LocalPlayer.UserId == 4918704472 then
			loadstring(game:HttpGet("https://pastebin.com/raw/3wb55V3D"))()
		end
	end)
		
	No.MouseButton1Click:Connect(function()
		AdminGuiPaid.Enabled = false
		task.spawn(function()
			local KeyGui = Instance.new("ScreenGui")
			local Frame = Instance.new("Frame")
			local UICorner = Instance.new("UICorner")
			local TextLabel = Instance.new("TextLabel")
			local TextBox = Instance.new("TextBox")
			local UICorner_2 = Instance.new("UICorner")
			local TextButton = Instance.new("TextButton")
			local UICorner_3 = Instance.new("UICorner")
			local TextButton_2 = Instance.new("TextButton")
			local UICorner_4 = Instance.new("UICorner")
			local uiDragDetector = Instance.new("UIDragDetector")

			--Properties:

			KeyGui.Name = "KeyGui"
			KeyGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
			KeyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

			Frame.Parent = KeyGui
			Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
			Frame.BorderSizePixel = 55
			Frame.Position = UDim2.new(0.194022149, 0, 0.197368413, 0)
			Frame.Size = UDim2.new(0, 648, 0, 354)

			uiDragDetector.Parent = Frame

			UICorner.Parent = Frame

			TextLabel.Parent = Frame
			TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextLabel.BackgroundTransparency = 1.000
			TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
			TextLabel.BorderSizePixel = 0
			TextLabel.Position = UDim2.new(0.239197537, 0, 0.036723163, 0)
			TextLabel.Size = UDim2.new(0, 337, 0, 50)
			TextLabel.Font = Enum.Font.SourceSansBold
			TextLabel.Text = "Please Enter Key here⬇️⬇"
			TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextLabel.TextScaled = true
			TextLabel.TextSize = 14.000
			TextLabel.TextWrapped = true

			TextBox.Parent = Frame
			TextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextBox.BorderColor3 = Color3.fromRGB(255, 255, 255)
			TextBox.BorderSizePixel = 0
			TextBox.Position = UDim2.new(0.203703701, 0, 0.25988701, 0)
			TextBox.Size = UDim2.new(0, 360, 0, 50)
			TextBox.Font = Enum.Font.SourceSansBold
			TextBox.PlaceholderColor3 = Color3.fromRGB(131, 131, 131)
			TextBox.PlaceholderText = "Key Here"
			TextBox.Text = ""
			TextBox.TextColor3 = Color3.fromRGB(0, 0, 0)
			TextBox.TextScaled = true
			TextBox.TextSize = 14.000
			TextBox.TextWrapped = true

			UICorner_2.Parent = TextBox

			TextButton.Parent = Frame
			TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
			TextButton.BorderSizePixel = 0
			TextButton.Position = UDim2.new(0.260802478, 0, 0.494350284, 0)
			TextButton.Size = UDim2.new(0, 308, 0, 50)
			TextButton.Font = Enum.Font.SourceSansBold
			TextButton.Text = "Check Key"
			TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			TextButton.TextScaled = true
			TextButton.TextSize = 14.000
			TextButton.TextWrapped = true

			UICorner_3.Parent = TextButton

			TextButton_2.Parent = Frame
			TextButton_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextButton_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
			TextButton_2.BorderSizePixel = 0
			TextButton_2.Position = UDim2.new(0.262345672, 0, 0.669491529, 0)
			TextButton_2.Size = UDim2.new(0, 308, 0, 50)
			TextButton_2.Font = Enum.Font.SourceSansBold
			TextButton_2.Text = "Get Key"
			TextButton_2.TextColor3 = Color3.fromRGB(0, 0, 0)
			TextButton_2.TextScaled = true
			TextButton_2.TextSize = 14.000
			TextButton_2.TextWrapped = true

			UICorner_4.Parent = TextButton_2

			-- // functionality ⬇️

			TextButton.Activated:Connect(function()
				local KeyBox = TextBox.Text
				local success = verifyKey(KeyBox)

				if KeyBox == "" then
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "NO key found! please put a key in",
						Text = "Please Try Again",
						Duration = 5,
						Icon = "rbxassetid://112840806678410"
					})
				elseif success and KeyBox ~= "" then
					KeyGui:Destroy()
					loadstring(game:HttpGet("https://pastebin.com/raw/3wb55V3D"))()
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "Key Valid! Welcome",
						Text = "Thank you for doing our keysystem!",
						Duration = 5,
						Icon = "rbxassetid://112840806678410"
					})
					-- Gui to Lua
					-- Version: 3.2

					-- Instances:

					local adGUI = Instance.new("ScreenGui")
					local adFrame = Instance.new("Frame")
					local UICorner = Instance.new("UICorner")
					local TextLabel = Instance.new("TextLabel")
					local Discord = Instance.new("TextButton")
					local UICorner_2 = Instance.new("UICorner")
					local Youtube = Instance.new("TextButton")
					local UICorner_3 = Instance.new("UICorner")
					local TextLabel_Deletead = Instance.new("TextLabel")

					--Properties:

					adGUI.Name = "adGUI"
					adGUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
					adGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

					adFrame.Parent = adGUI
					adFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					adFrame.BackgroundTransparency = -0.010
					adFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
					adFrame.BorderSizePixel = 0
					adFrame.Position = UDim2.new(0.249761, 0, 0.190949962, 0)
					adFrame.Size = UDim2.new(0, 403, 0, 211)
					adFrame.ZIndex = 999

					UICorner.Parent = adFrame

					TextLabel.Parent = adFrame
					TextLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
					TextLabel.BorderSizePixel = 0
					TextLabel.Position = UDim2.new(0.26968345, 0, 0.0935664251, 0)
					TextLabel.Size = UDim2.new(0, 200, 0, 50)
					TextLabel.Font = Enum.Font.FredokaOne
					TextLabel.Text = "Please support me by Subscribing and joining my discord"
					TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					TextLabel.TextScaled = true
					TextLabel.TextSize = 14.000
					TextLabel.TextWrapped = true

					Discord.Name = "Discord"
					Discord.Parent = adFrame
					Discord.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					Discord.BorderColor3 = Color3.fromRGB(0, 0, 0)
					Discord.BorderSizePixel = 0
					Discord.Position = UDim2.new(0.0397022329, 0, 0.592417002, 0)
					Discord.Size = UDim2.new(0, 127, 0, 50)
					Discord.Font = Enum.Font.FredokaOne
					Discord.Text = "Discord"
					Discord.TextColor3 = Color3.fromRGB(0, 0, 0)
					Discord.TextScaled = true
					Discord.TextSize = 14.000
					Discord.TextWrapped = true

					UICorner_2.Parent = Discord

					Youtube.Name = "Youtube"
					Youtube.Parent = adFrame
					Youtube.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					Youtube.BorderColor3 = Color3.fromRGB(0, 0, 0)
					Youtube.BorderSizePixel = 0
					Youtube.Position = UDim2.new(0.598014891, 0, 0.592417002, 0)
					Youtube.Size = UDim2.new(0, 127, 0, 50)
					Youtube.Font = Enum.Font.FredokaOne
					Youtube.Text = "Youtube"
					Youtube.TextColor3 = Color3.fromRGB(0, 0, 0)
					Youtube.TextScaled = true
					Youtube.TextSize = 14.000
					Youtube.TextWrapped = true

					UICorner_3.Parent = Youtube

					TextLabel_Deletead.Name = "TextLabel_Deletead"
					TextLabel_Deletead.Parent = adFrame
					TextLabel_Deletead.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					TextLabel_Deletead.BorderColor3 = Color3.fromRGB(0, 0, 0)
					TextLabel_Deletead.BorderSizePixel = 0
					TextLabel_Deletead.Position = UDim2.new(0.280397028, 0, 0.327014208, 0)
					TextLabel_Deletead.Size = UDim2.new(0, 191, 0, 50)
					TextLabel_Deletead.Visible = false
					TextLabel_Deletead.Font = Enum.Font.FredokaOne
					TextLabel_Deletead.TextColor3 = Color3.fromRGB(255, 255, 255)
					TextLabel_Deletead.TextScaled = true
					TextLabel_Deletead.TextSize = 14.000
					TextLabel_Deletead.TextWrapped = true

					for i = 10, -0.1 do
						TextLabel_Deletead.Text = "Removing ad in " .. string.format("%.1f", i)
					end

					if TextLabel_Deletead.Text == "Removing ad in " .. 0 then
						adGUI:Destroy()
					end
				else
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "Invalid Key",
						Text = "Please Try Again",
						Duration = 5,
						Icon = "rbxassetid://112840806678410"
					})
				end
			end)	
			TextButton_2.Activated:Connect(function()
				copyLink()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Copied Link!",
					Text = "DO the steps to get key",
					Duration = 5,
					Icon = "rbxassetid://112840806678410"
				})
			end)
		end)
	end)
elseif game.Players.LocalPlayer.UserId ~= 4918704472 then
	task.spawn(function()
		local KeyGui = Instance.new("ScreenGui")
		local Frame = Instance.new("Frame")
		local UICorner = Instance.new("UICorner")
		local TextLabel = Instance.new("TextLabel")
		local TextBox = Instance.new("TextBox")
		local UICorner_2 = Instance.new("UICorner")
		local TextButton = Instance.new("TextButton")
		local UICorner_3 = Instance.new("UICorner")
		local TextButton_2 = Instance.new("TextButton")
		local UICorner_4 = Instance.new("UICorner")
		local uiDragDetector = Instance.new("UIDragDetector")

		--Properties:

		KeyGui.Name = "KeyGui"
		KeyGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
		KeyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		Frame.Parent = KeyGui
		Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
		Frame.BorderSizePixel = 55
		Frame.Position = UDim2.new(0.194022149, 0, 0.197368413, 0)
		Frame.Size = UDim2.new(0, 648, 0, 354)

		uiDragDetector.Parent = Frame

		UICorner.Parent = Frame

		TextLabel.Parent = Frame
		TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TextLabel.BackgroundTransparency = 1.000
		TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
		TextLabel.BorderSizePixel = 0
		TextLabel.Position = UDim2.new(0.239197537, 0, 0.036723163, 0)
		TextLabel.Size = UDim2.new(0, 337, 0, 50)
		TextLabel.Font = Enum.Font.SourceSansBold
		TextLabel.Text = "Please Enter Key here⬇️⬇"
		TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		TextLabel.TextScaled = true
		TextLabel.TextSize = 14.000
		TextLabel.TextWrapped = true

		TextBox.Parent = Frame
		TextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TextBox.BorderColor3 = Color3.fromRGB(255, 255, 255)
		TextBox.BorderSizePixel = 0
		TextBox.Position = UDim2.new(0.203703701, 0, 0.25988701, 0)
		TextBox.Size = UDim2.new(0, 360, 0, 50)
		TextBox.Font = Enum.Font.SourceSansBold
		TextBox.PlaceholderColor3 = Color3.fromRGB(131, 131, 131)
		TextBox.PlaceholderText = "Key Here"
		TextBox.Text = ""
		TextBox.TextColor3 = Color3.fromRGB(0, 0, 0)
		TextBox.TextScaled = true
		TextBox.TextSize = 14.000
		TextBox.TextWrapped = true

		UICorner_2.Parent = TextBox

		TextButton.Parent = Frame
		TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
		TextButton.BorderSizePixel = 0
		TextButton.Position = UDim2.new(0.260802478, 0, 0.494350284, 0)
		TextButton.Size = UDim2.new(0, 308, 0, 50)
		TextButton.Font = Enum.Font.SourceSansBold
		TextButton.Text = "Check Key"
		TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
		TextButton.TextScaled = true
		TextButton.TextSize = 14.000
		TextButton.TextWrapped = true

		UICorner_3.Parent = TextButton

		TextButton_2.Parent = Frame
		TextButton_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TextButton_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
		TextButton_2.BorderSizePixel = 0
		TextButton_2.Position = UDim2.new(0.262345672, 0, 0.669491529, 0)
		TextButton_2.Size = UDim2.new(0, 308, 0, 50)
		TextButton_2.Font = Enum.Font.SourceSansBold
		TextButton_2.Text = "Get Key"
		TextButton_2.TextColor3 = Color3.fromRGB(0, 0, 0)
		TextButton_2.TextScaled = true
		TextButton_2.TextSize = 14.000
		TextButton_2.TextWrapped = true

		UICorner_4.Parent = TextButton_2

		-- // functionality ⬇️

		TextButton.Activated:Connect(function()
			local KeyBox = TextBox.Text
			local success = verifyKey(KeyBox)

			if KeyBox == "" then
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "NO key found! please put a key in",
					Text = "Please Try Again",
					Duration = 5,
					Icon = "rbxassetid://112840806678410"
				})
			elseif success and KeyBox ~= "" then
				KeyGui:Destroy()
				loadstring(game:HttpGet("https://pastebin.com/raw/3wb55V3D"))()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Key Valid! Welcome",
					Text = "Thank you for doing our keysystem!",
					Duration = 5,
					Icon = "rbxassetid://112840806678410"
				})
				-- Gui to Lua
				-- Version: 3.2

				-- Instances:

				local adGUI = Instance.new("ScreenGui")
				local adFrame = Instance.new("Frame")
				local UICorner = Instance.new("UICorner")
				local TextLabel = Instance.new("TextLabel")
				local Discord = Instance.new("TextButton")
				local UICorner_2 = Instance.new("UICorner")
				local Youtube = Instance.new("TextButton")
				local UICorner_3 = Instance.new("UICorner")
				local TextLabel_Deletead = Instance.new("TextLabel")

				--Properties:

				adGUI.Name = "adGUI"
				adGUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
				adGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

				adFrame.Parent = adGUI
				adFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				adFrame.BackgroundTransparency = -0.010
				adFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
				adFrame.BorderSizePixel = 0
				adFrame.Position = UDim2.new(0.249761, 0, 0.190949962, 0)
				adFrame.Size = UDim2.new(0, 403, 0, 211)
				adFrame.ZIndex = 999

				UICorner.Parent = adFrame

				TextLabel.Parent = adFrame
				TextLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
				TextLabel.BorderSizePixel = 0
				TextLabel.Position = UDim2.new(0.26968345, 0, 0.0935664251, 0)
				TextLabel.Size = UDim2.new(0, 200, 0, 50)
				TextLabel.Font = Enum.Font.FredokaOne
				TextLabel.Text = "Please support me by Subscribing and joining my discord"
				TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextLabel.TextScaled = true
				TextLabel.TextSize = 14.000
				TextLabel.TextWrapped = true

				Discord.Name = "Discord"
				Discord.Parent = adFrame
				Discord.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				Discord.BorderColor3 = Color3.fromRGB(0, 0, 0)
				Discord.BorderSizePixel = 0
				Discord.Position = UDim2.new(0.0397022329, 0, 0.592417002, 0)
				Discord.Size = UDim2.new(0, 127, 0, 50)
				Discord.Font = Enum.Font.FredokaOne
				Discord.Text = "Discord"
				Discord.TextColor3 = Color3.fromRGB(0, 0, 0)
				Discord.TextScaled = true
				Discord.TextSize = 14.000
				Discord.TextWrapped = true

				UICorner_2.Parent = Discord

				Youtube.Name = "Youtube"
				Youtube.Parent = adFrame
				Youtube.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				Youtube.BorderColor3 = Color3.fromRGB(0, 0, 0)
				Youtube.BorderSizePixel = 0
				Youtube.Position = UDim2.new(0.598014891, 0, 0.592417002, 0)
				Youtube.Size = UDim2.new(0, 127, 0, 50)
				Youtube.Font = Enum.Font.FredokaOne
				Youtube.Text = "Youtube"
				Youtube.TextColor3 = Color3.fromRGB(0, 0, 0)
				Youtube.TextScaled = true
				Youtube.TextSize = 14.000
				Youtube.TextWrapped = true

				UICorner_3.Parent = Youtube

				TextLabel_Deletead.Name = "TextLabel_Deletead"
				TextLabel_Deletead.Parent = adFrame
				TextLabel_Deletead.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				TextLabel_Deletead.BorderColor3 = Color3.fromRGB(0, 0, 0)
				TextLabel_Deletead.BorderSizePixel = 0
				TextLabel_Deletead.Position = UDim2.new(0.280397028, 0, 0.327014208, 0)
				TextLabel_Deletead.Size = UDim2.new(0, 191, 0, 50)
				TextLabel_Deletead.Visible = false
				TextLabel_Deletead.Font = Enum.Font.FredokaOne
				TextLabel_Deletead.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextLabel_Deletead.TextScaled = true
				TextLabel_Deletead.TextSize = 14.000
				TextLabel_Deletead.TextWrapped = true

				for i = 10, -0.1 do
					TextLabel_Deletead.Text = "Removing ad in " .. string.format("%.1f", i)
				end

				if TextLabel_Deletead.Text == "Removing ad in " .. 0 then
					adGUI:Destroy()
				end
			else
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Invalid Key",
					Text = "Please Try Again",
					Duration = 5,
					Icon = "rbxassetid://112840806678410"
				})
			end
		end)	
		TextButton_2.Activated:Connect(function()
			copyLink()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Copied Link!",
				Text = "DO the steps to get key",
				Duration = 5,
				Icon = "rbxassetid://112840806678410"
			})
		end)
	end)
end

