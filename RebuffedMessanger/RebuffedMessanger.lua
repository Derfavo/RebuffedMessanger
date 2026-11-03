local M = {contacts = {}, order = {}, detached = {}}
RebuffedMessanger = M
local main, refreshList, createWindow, render, selectContact
local VISIBLE, ROW_HEIGHT, MAX_MESSAGES = 11, 23, 150
local german = GetLocale() == "deDE"
local function text(de, en) return german and de or en end
local function cleanName(name)
    if type(name) ~= "string" then return end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 64 or name:find("[%c%s|]") then return end
    return name
end
local function settings()
    if type(RebuffedMessangerDB) ~= "table" then RebuffedMessangerDB = {} end
    if type(RebuffedMessangerDB.positions) ~= "table" then RebuffedMessangerDB.positions = {} end
    return RebuffedMessangerDB.positions
end
local function getContact(name)
    name = cleanName(name)
    if not name then return end
    local key = name:lower()
    if not M.contacts[key] then
        M.contacts[key] = {key = key, name = name, messages = {}, unread = 0}
        M.order[#M.order + 1] = key
    end
    return M.contacts[key]
end
local function savePosition(window)
    local x, y = window:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if x and y and cx and cy then settings()[window.positionKey] = {x = x-cx, y = y-cy} end
end
local function restorePosition(window)
    local saved = settings()[window.positionKey]
    window:ClearAllPoints()
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
        window:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", main and 35 or 0, main and -35 or 0)
    end
end
local function formatMessage(message)
    local name = message.outgoing and text("Ich", "Me") or message.author
    local color = message.outgoing and "|cff80ff90" or "|cff80c8ff"
    return "|cff999999[" .. message.stamp .. "]|r " .. color .. name .. ":|r " .. message.text
end
render = function(window)
    window.messages:Clear()
    local contact = window.contact and M.contacts[window.contact]
    window.target:SetText(contact and contact.name or text("Gespräch auswählen", "Select a conversation"))
    if contact then
        for _, message in ipairs(contact.messages) do window.messages:AddMessage(formatMessage(message)) end
        contact.unread = 0
    end
    window.messages:ScrollToBottom()
    window.input:SetText(window.drafts[window.contact or ""] or "")
end
local function button(parent, label, width, point, relative, relativePoint, x, y, click)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(22); b:SetPoint(point,relative,relativePoint,x,y)
    b:SetText(label); b:SetScript("OnClick",click)
    return b
end
local function sendInput(window)
    local contact = window.contact and M.contacts[window.contact]
    local message = window.input:GetText():match("^%s*(.-)%s*$")
    if not contact or message == "" then return end
    if #message > 255 then
        DEFAULT_CHAT_FRAME:AddMessage("RebuffedMessanger: " .. text("Nachricht zu lang (max. 255 Bytes).", "Message too long (255 bytes maximum)."))
        return
    end
    local ok = pcall(SendChatMessage,message,"WHISPER",nil,contact.name)
    if ok then
        window.drafts[contact.key] = ""
        window.input:SetText("")
    else
        DEFAULT_CHAT_FRAME:AddMessage("RebuffedMessanger: " .. text("Nachricht konnte nicht gesendet werden. Der Entwurf bleibt erhalten.", "Could not send the message. Your draft has been kept."))
    end
end
createWindow = function(positionKey, isMain)
    local window = CreateFrame("Frame", isMain and "RebuffedMessangerMain" or nil, UIParent)
    window.positionKey, window.drafts = positionKey, {}
    window:SetWidth(isMain and 690 or 460); window:SetHeight(isMain and 390 or 320)
    window:SetFrameStrata("DIALOG"); window:SetToplevel(true); window:SetClampedToScreen(true)
    window:SetMovable(true); window:EnableMouse(true)
    window:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    window:SetBackdropColor(0.04,0.05,0.08,0.96)
    local title = CreateFrame("Frame",nil,window)
    title:SetPoint("TOPLEFT",8,-6); title:SetPoint("TOPRIGHT",-36,-6); title:SetHeight(25)
    title:EnableMouse(true); title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart",function() window:StartMoving() end)
    title:SetScript("OnDragStop",function() window:StopMovingOrSizing(); savePosition(window) end)
    local heading = title:CreateFontString(nil,"OVERLAY","GameFontNormal")
    heading:SetPoint("LEFT",4,0); heading:SetText("RebuffedMessanger")
    window.close = button(window,"X",24,"TOPRIGHT",window,"TOPRIGHT",-8,-7,function()
        if isMain then window:Hide() elseif window.contact then M.Attach(window.contact,false) end
    end)
    window.target = window:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local left = isMain and 190 or 15
    window.target:SetPoint("TOPLEFT",left,-42); window.target:SetWidth(isMain and 340 or 295); window.target:SetJustifyH("LEFT")
    window.moveButton = button(window,isMain and text("Abtrennen","Detach") or text("Andocken","Attach"),100,"TOPRIGHT",window,"TOPRIGHT",-12,-36,function()
        if not window.contact then return end
        if isMain then M.Detach(window.contact) else M.Attach(window.contact,true) end
    end)
    window.messages = CreateFrame("ScrollingMessageFrame",nil,window)
    window.messages:SetPoint("TOPLEFT",left,-70); window.messages:SetPoint("BOTTOMRIGHT",-17,52)
    window.messages:SetFontObject("ChatFontNormal"); window.messages:SetJustifyH("LEFT")
    window.messages:SetFading(false); window.messages:SetMaxLines(MAX_MESSAGES)
    window.messages:EnableMouse(true); window.messages:EnableMouseWheel(true); window.messages:SetHyperlinksEnabled(true)
    window.messages:SetScript("OnMouseWheel",function(self,delta) if delta>0 then self:ScrollUp() else self:ScrollDown() end end)
    window.messages:SetScript("OnHyperlinkClick",function(self,link,label,mouse) SetItemRef(link,label,mouse,DEFAULT_CHAT_FRAME) end)
    window.input = CreateFrame("EditBox",nil,window,"InputBoxTemplate")
    window.input:SetPoint("BOTTOMLEFT",left+5,17); window.input:SetPoint("BOTTOMRIGHT",-95,17)
    window.input:SetHeight(24); window.input:SetFontObject("ChatFontNormal")
    window.input:SetAutoFocus(false); window.input:SetMaxLetters(255)
    window.input:SetScript("OnEnterPressed",function() sendInput(window) end)
    window.input:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    window.input:SetScript("OnTextChanged",function(self) if window.contact then window.drafts[window.contact] = self:GetText() end end)
    window.send = button(window,text("Senden","Send"),70,"BOTTOMRIGHT",window,"BOTTOMRIGHT",-14,18,function() sendInput(window) end)
    window:SetScript("OnHide",function() window.input:ClearFocus() end)
    restorePosition(window); window:Hide()
    return window
end
local function ensureMain()
    if main then return main end
    main = createWindow("main",true)
    M.main = main
    local caption = main:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    caption:SetPoint("TOPLEFT",16,-42); caption:SetText(text("Neues Gespräch:","New conversation:"))
    local nameInput = CreateFrame("EditBox",nil,main,"InputBoxTemplate")
    nameInput:SetPoint("TOPLEFT",22,-65); nameInput:SetWidth(112); nameInput:SetHeight(22)
    nameInput:SetAutoFocus(false); nameInput:SetFontObject("ChatFontNormal"); nameInput:SetMaxLetters(64)
    local function openName() M.Open(nameInput:GetText(),true); nameInput:ClearFocus() end
    nameInput:SetScript("OnEnterPressed",openName)
    nameInput:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    main.newName = nameInput
    button(main,"+",28,"TOPLEFT",main,"TOPLEFT",143,-65,openName)
    main.list = CreateFrame("ScrollFrame","RebuffedMessangerContactsScroll",main,"FauxScrollFrameTemplate")
    main.list:SetPoint("TOPLEFT",14,-101); main.list:SetWidth(146); main.list:SetHeight(VISIBLE*ROW_HEIGHT)
    main.list:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,ROW_HEIGHT,refreshList) end)
    main.list:EnableMouseWheel(true)
    main.list:SetScript("OnMouseWheel",function(self,delta)
        local offset=FauxScrollFrame_GetOffset(self)-delta*3
        FauxScrollFrame_SetOffset(self,math.max(0,math.min(offset,math.max(0,#main.listed-VISIBLE))))
        refreshList()
    end)
    main.rows = {}
    for index=1,VISIBLE do
        local row=CreateFrame("Button",nil,main)
        row:SetWidth(151); row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT",16,-101-(index-1)*ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.label:SetAllPoints(); row.label:SetJustifyH("LEFT")
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnClick",function(self)
            if self.key and not self.dragging and (not self.ignoreClickUntil or GetTime()>=self.ignoreClickUntil) then selectContact(self.key,true) end
        end)
        row:SetScript("OnDragStart",function(self) self.dragging=self.key end)
        row:SetScript("OnDragStop",function(self)
            local key=self.dragging; self.dragging=nil
            self.ignoreClickUntil=GetTime()+0.2
            if key then
                local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale()
                M.Detach(key,x/scale,y/scale)
            end
        end)
        row:SetScript("OnEnter",function(self)
            if not self.key then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(M.contacts[self.key].name)
            GameTooltip:AddLine(text("Klicken: öffnen. Herausziehen: eigenes Fenster.","Click to open. Drag out for a separate window."),1,1,1,true); GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        main.rows[index]=row
    end
    main.listed={}
    render(main)
    return main
end
refreshList = function()
    if not main then return end
    local listed={}
    for _,key in ipairs(M.order) do if not M.contacts[key].detached then listed[#listed+1]=key end end
    main.listed=listed
    local offset=math.min(FauxScrollFrame_GetOffset(main.list),math.max(0,#listed-VISIBLE))
    FauxScrollFrame_SetOffset(main.list,offset)
    FauxScrollFrame_Update(main.list,#listed,VISIBLE,ROW_HEIGHT)
    for index,row in ipairs(main.rows) do
        local key=listed[index+offset]
        row.key=key
        if key then
            local contact=M.contacts[key]
            local color=key==main.contact and "|cffffd100" or contact.unread>0 and "|cff80ff90" or "|cffffffff"
            row.label:SetText(color..contact.name..(contact.unread>0 and " ("..contact.unread..")" or "").."|r")
            row:Show()
        else row:Hide() end
    end
end
selectContact = function(key,focus)
    local window=ensureMain()
    window.contact=key
    window:Show(); render(window); refreshList()
    if focus then window.input:SetFocus() end
end
function M.Open(name,focus)
    local contact=getContact(name)
    if not contact then return false end
    if contact.detached then
        local window=M.detached[contact.key]
        window:Show(); render(window)
        if focus then window.input:SetFocus() end
    else selectContact(contact.key,focus) end
    return true
end
function M.Detach(name,x,y)
    local contact=getContact(name)
    if not contact then return end
    ensureMain()
    local window=M.detached[contact.key]
    if not window then window=createWindow("contact:"..contact.key,false); M.detached[contact.key]=window end
    local draft=main.drafts[contact.key]
    if draft then window.drafts[contact.key]=draft; main.drafts[contact.key]=nil end
    contact.detached=true; window.contact=contact.key
    if x and y then window:ClearAllPoints(); window:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y); savePosition(window) end
    window:Show(); render(window)
    if main.contact==contact.key then
        main.contact=nil
        for _,key in ipairs(M.order) do if not M.contacts[key].detached then main.contact=key; break end end
        render(main)
    end
    refreshList()
end
function M.Attach(name,show)
    local contact=getContact(name)
    if not contact then return end
    local window=M.detached[contact.key]
    if window then
        main.drafts[contact.key]=window.drafts[contact.key]
        window.drafts[contact.key]=nil; window:Hide(); window.contact=nil
    end
    contact.detached=false
    refreshList()
    if show then selectContact(contact.key,true) end
end
function M.Receive(event,message,author)
    if type(message)~="string" then return end
    local contact=getContact(author)
    if not contact then return end
    local outgoing=event=="CHAT_MSG_WHISPER_INFORM"
    if outgoing then
        M.lastOutgoing=contact.name
        if ChatEdit_SetLastToldTarget then ChatEdit_SetLastToldTarget(contact.name) end
    else
        M.lastIncoming=contact.name
        if ChatEdit_SetLastTellTarget then ChatEdit_SetLastTellTarget(contact.name) end
    end
    contact.messages[#contact.messages+1]={text=message,author=contact.name,outgoing=outgoing,stamp=date("%H:%M")}
    if #contact.messages>MAX_MESSAGES then table.remove(contact.messages,1) end
    local window=contact.detached and M.detached[contact.key] or ensureMain()
    local changed=false
    if contact.detached then
        window:Show()
    elseif not window:IsShown() or not window.contact or outgoing then
        changed=window.contact~=contact.key
        window.contact=contact.key; window:Show()
    end
    if window.contact==contact.key and window:IsShown() then
        if changed then render(window)
        else
            local atBottom=not window.messages.AtBottom or window.messages:AtBottom()
            window.messages:AddMessage(formatMessage(contact.messages[#contact.messages]))
            if atBottom then window.messages:ScrollToBottom() end
            contact.unread=0
        end
    else contact.unread=contact.unread+1 end
    refreshList()
end
local events=CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_WHISPER"); events:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(self,event,...)
    if event=="PLAYER_LOGIN" then settings() else M.Receive(event,...) end
end)
if ChatFrame_AddMessageEventFilter then
    local function filter(self,event,message,author)
        return type(message)=="string" and cleanName(author)~=nil
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",filter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM",filter)
end
local originalTell=ChatFrame_SendTell
ChatFrame_SendTell=function(name,...)
    if not M.Open(name,true) and originalTell then return originalTell(name,...) end
end
local originalReply,originalReply2=ChatFrame_ReplyTell,ChatFrame_ReplyTell2
ChatFrame_ReplyTell=function(...)
    local name=M.lastIncoming or (ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget())
    if not M.Open(name,true) and originalReply then return originalReply(...) end
end
ChatFrame_ReplyTell2=function(...)
    local name=M.lastOutgoing or (ChatEdit_GetLastToldTarget and ChatEdit_GetLastToldTarget())
    if not M.Open(name,true) and originalReply2 then return originalReply2(...) end
end
local redirecting=false
local function redirectComposer(editBox)
    if redirecting or not editBox or not editBox:IsShown() or not editBox:HasFocus()
        or editBox:GetAttribute("chatType")~="WHISPER" then return end
    local name=cleanName(editBox:GetAttribute("tellTarget"))
    local body=editBox:GetText()
    if not name or body:sub(1,1)=="/" then return end
    local contact=getContact(name)
    local window=contact.detached and M.detached[contact.key] or ensureMain()
    local existing=window.drafts[contact.key]
    -- Never replace a separate unsent draft with text already composed elsewhere.
    if body~="" and existing and existing~="" then return end
    redirecting=true
    if body~="" then window.drafts[contact.key]=body end
    editBox:SetText("")
    if ChatEdit_DeactivateChat then ChatEdit_DeactivateChat(editBox)
    else editBox:ClearFocus(); editBox:Hide() end
    M.Open(name,true)
    redirecting=false
end
if hooksecurefunc then
    if ChatEdit_OnSpacePressed then hooksecurefunc("ChatEdit_OnSpacePressed",redirectComposer) end
    if ChatEdit_OnTextChanged then
        hooksecurefunc("ChatEdit_OnTextChanged",function(editBox,userInput) if userInput then redirectComposer(editBox) end end)
    end
end
SLASH_REBUFFEDMESSANGER1="/rmsg"
SLASH_REBUFFEDMESSANGER2="/messanger"
SlashCmdList.REBUFFEDMESSANGER=function(name)
    if cleanName(name) then M.Open(name,true)
    else local window=ensureMain(); window:Show(); refreshList() end
end
