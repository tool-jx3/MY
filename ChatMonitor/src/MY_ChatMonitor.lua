--
-- ������
-- by ���� @ ˫���� @ ݶ����
-- Build 20140411
--
-- ��Ҫ����: ���ؼ��ֹ��˻�ȡ������Ϣ
--
--[[
    MY_ChatMonitor.tRecords = {
        -- �����鲿�֣���ؼ�¼
        {
            html = ��ϢA��UI���л�ֵ(szMsg) ��ϢԴ����UI XML,
            hash = ��ϢA��HASHֵ ���㵱ǰ��Ϣ�Ĺ�ϣ ���ڹ�����ͬ,
            text = ��ϢA�Ĵ��ı� ���㵱ǰ��Ϣ�Ĵ��������� ����ƥ��,
        }, ...
        -- ����ϣ���֣���¼����
        [��ϢA��HASHֵ] = ��ͬ����ϢA���������, -- ��Ϊ0ʱɾ����HASH
        ...
    }
]]
local _C = {}
local _L = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. "ChatMonitor/lang/")
MY_ChatMonitor = {}
MY_ChatMonitor.szKeyWords          = _L.CHAT_MONITOR_KEYWORDS_SAMPLE
MY_ChatMonitor.bIsRegexp           = false
MY_ChatMonitor.nMaxRecord          = 30
MY_ChatMonitor.bShowPreview        = true
MY_ChatMonitor.bPlaySound          = true
MY_ChatMonitor.bRedirectSysChannel = false
MY_ChatMonitor.bCapture            = false
MY_ChatMonitor.bBlockWords         = true
MY_ChatMonitor.bIgnoreSame         = true
MY_ChatMonitor.szTimestrap         = "[hh:mm:ss]"
MY_ChatMonitor.tChannels           = { ["MSG_NORMAL"] = true, ["MSG_CAMP"] = true, ["MSG_WORLD"] = true, ["MSG_MAP"] = true, ["MSG_SCHOOL"] = true, ["MSG_GUILD"] = true, ["MSG_FRIEND"] = true, ["MSG_IDENTITY"] = true }
MY_ChatMonitor.anchor              = { x = -100, y = -150, s = "BOTTOMRIGHT", r = "BOTTOMRIGHT" }
MY_ChatMonitor.tRecords            = {}
RegisterCustomData('MY_ChatMonitor.szKeyWords')
RegisterCustomData('MY_ChatMonitor.bIsRegexp')
RegisterCustomData('MY_ChatMonitor.nMaxRecord')
RegisterCustomData('MY_ChatMonitor.bShowPreview')
RegisterCustomData('MY_ChatMonitor.bCapture')
RegisterCustomData('MY_ChatMonitor.bBlockWords')
RegisterCustomData('MY_ChatMonitor.tChannels')
RegisterCustomData('MY_ChatMonitor.bPlaySound')
RegisterCustomData('MY_ChatMonitor.bRedirectSysChannel')
RegisterCustomData('MY_ChatMonitor.anchor')
RegisterCustomData('MY_ChatMonitor.bIgnoreSame')
RegisterCustomData('MY_ChatMonitor.szTimestrap')
RegisterCustomData('MY_ChatMonitor.tRecords')
_C.bInited = false
_C.ui = nil
_C.uiBoard = nil
_C.uiTipBoard = nil
_C.szLuaData = 'config/MY_CHATMONITOR/cfg_$lang.jx3dat'
_C.tChannelGroups = {
    {
        szCaption = g_tStrings.CHANNEL_CHANNEL,
        tChannels = {
            "MSG_NORMAL", "MSG_PARTY", "MSG_MAP", "MSG_BATTLE_FILED", "MSG_GUILD", "MSG_GUILD_ALLIANCE", "MSG_SCHOOL", "MSG_WORLD",
            "MSG_TEAM", "MSG_CAMP", "MSG_GROUP", "MSG_WHISPER", "MSG_SEEK_MENTOR", "MSG_FRIEND", "MSG_IDENTITY", "MSG_SYS",
        },
    }, {
        szCaption = g_tStrings.FIGHT_CHANNEL,
        tChannels = {
            [g_tStrings.STR_NAME_OWN] = {
                "MSG_SKILL_SELF_HARMFUL_SKILL", "MSG_SKILL_SELF_BENEFICIAL_SKILL", "MSG_SKILL_SELF_BUFF",
                "MSG_SKILL_SELF_BE_HARMFUL_SKILL", "MSG_SKILL_SELF_BE_BENEFICIAL_SKILL", "MSG_SKILL_SELF_DEBUFF",
                "MSG_SKILL_SELF_SKILL", "MSG_SKILL_SELF_MISS", "MSG_SKILL_SELF_FAILED", "MSG_SELF_DEATH",
            },
            [g_tStrings.TEAMMATE] = {
                "MSG_SKILL_PARTY_HARMFUL_SKILL", "MSG_SKILL_PARTY_BENEFICIAL_SKILL", "MSG_SKILL_PARTY_BUFF",
                "MSG_SKILL_PARTY_BE_HARMFUL_SKILL", "MSG_SKILL_PARTY_BE_BENEFICIAL_SKILL", "MSG_SKILL_PARTY_DEBUFF",
                "MSG_SKILL_PARTY_SKILL", "MSG_SKILL_PARTY_MISS", "MSG_PARTY_DEATH",
            },
            [g_tStrings.OTHER_PLAYER] = {"MSG_SKILL_OTHERS_SKILL", "MSG_SKILL_OTHERS_MISS", "MSG_OTHERS_DEATH"},
            ["NPC"] = {"MSG_SKILL_NPC_SKILL", "MSG_SKILL_NPC_MISS", "MSG_NPC_DEATH"},
            [g_tStrings.OTHER] = {"MSG_OTHER_ENCHANT", "MSG_OTHER_SCENE"},
        },
    }, {
        szCaption = g_tStrings.CHANNEL_COMMON,
        tChannels = {
            [g_tStrings.ENVIROMENT] = {"MSG_NPC_NEARBY", "MSG_NPC_YELL", "MSG_NPC_PARTY", "MSG_NPC_WHISPER"},
            [g_tStrings.EARN] = {
                "MSG_MONEY", "MSG_EXP", "MSG_ITEM", "MSG_REPUTATION", "MSG_CONTRIBUTE",
                "MSG_ATTRACTION", "MSG_PRESTIGE", "MSG_TRAIN", "MSG_DESGNATION",
                "MSG_ACHIEVEMENT", "MSG_MENTOR_VALUE", "MSG_THEW_STAMINA", "MSG_TONG_FUND"
            },
        },
    }
}
_C.nLastLoadDataTime = -1000000

-- ������������ʱ���������Ϣ
_C.OnMsgArrive = function(szMsg, nFont, bRich, r, g, b, szChannel)
    -- is enabled
    if not MY_ChatMonitor.bCapture
    or not MY_ChatMonitor.szKeyWords
    or MY_ChatMonitor.szKeyWords == '' then
        return
    end
    if MY_ChatMonitor.bBlockWords
    and MY_Chat and MY_Chat.MatchBlockWord
    and MY_Chat.MatchBlockWord(szMsg, szChannel, bRich) then
        return
    end
    --------------------------------------------------------------------------------------
    -- ��ʼ����һ����¼
    local rec = { text = '', hash = '', html = '' }
    -- ������ϢԴ����UI
    if bRich then
        rec.html = szMsg
        -- ��ʽ����Ϣ
        local tMsgContent = MY.Chat.FormatContent(szMsg)
        -- �����Ϣ�Ƿ��ǲ���Լ�������
        if tMsgContent[1].type == "text" and tMsgContent[1].displayText == "" then
            return
        end
        -- ƴ����Ϣ
        if szChannel == "MSG_SYS" then -- ϵͳ��Ϣ
            for i, v in ipairs(tMsgContent) do
                rec.text = rec.text .. v.text
            end
        else -- �������ϵͳ��Ϣ��������һ������֮ǰ�Ķ��� ���ơ�[��Ӫ][������][����]˵����
            -- STR_TALK_HEAD_WHISPER = "���ĵ�˵��",
            -- STR_TALK_HEAD_WHISPER_REPLY = "�����ĵض�",
            -- STR_TALK_HEAD_SAY = "˵��",
            -- STR_TALK_HEAD_SAY1 = "��",
            -- STR_TALK_HEAD_SAY2 = "��������",
            local bSkiped = false
            for i, v in ipairs(tMsgContent) do
                if (i < 4 and not bSkiped) and (
                    v.text == g_tStrings.STR_TALK_HEAD_WHISPER or
                    v.text == g_tStrings.STR_TALK_HEAD_SAY or
                    v.text == g_tStrings.STR_TALK_HEAD_SAY1 or
                    v.text == g_tStrings.STR_TALK_HEAD_SAY2
                ) then
                    bSkiped = true
                    rec.text = ''
                else
                    rec.text = rec.text .. v.text
                end
            end
        end
    else
        rec.text = szMsg
        rec.html = GetFormatText(szMsg, nil, GetMsgFontColor("MSG_SYS"))
    end
    
    if not MY_ChatMonitor.bIsRegexp then
        rec.text = StringLowerW(rec.text)
    end
    rec.hash = string.gsub(rec.text, '[\n%s]+', '')
    --------------------------------------------------------------------------------------
    -- ��ʼ�����Ƿ���Ϲ�����Ҫ��
    if MY_ChatMonitor.bIsRegexp then -- regexp
        if not string.find(rec.text, MY_ChatMonitor.szKeyWords) then
            return
        end
    else -- normal
        if not MY.String.SimpleMatch(rec.text, MY_ChatMonitor.szKeyWords) then
            return
        end
    end
    local tRecords = MY_ChatMonitor.tRecords
    -- ��֤��Ϣ��ϣ �����������������Ϣ
    if MY_ChatMonitor.bIgnoreSame and tRecords[rec.hash] then
        return
    end
    --------------------------------------------------------------------------------------
    -- �������Ҫ��
    -- ��ʼ��Ⱦһ����¼��UIXML�ַ���
    rec.html = MY.Chat.GetTimeLinkText({r=r, g=g, b=b, f=nFont, s=MY_ChatMonitor.szTimestrap}) .. rec.html
    -- render link event
    rec.html = MY.Chat.RenderLink(rec.html)
    -- render player name color
    if MY_Farbnamen and MY_Farbnamen.Render then
        rec.html = MY_Farbnamen.Render(rec.html)
    end
    -- ������ʾ��
    if MY_ChatMonitor.bPlaySound then
        MY.Sys.PlaySound(MY.GetAddonInfo().szRoot .. "ChatMonitor\\audio\\MsgArrive.wav", "MsgArrive.wav")
    end
    -- ��������ض���ϵͳ��Ϣ����������ʱ�Ӹ���Ƿ�ֹ�ֱ��Լ���׽����ѭ����
    if MY_ChatMonitor.bRedirectSysChannel and szChannel ~= "MSG_SYS" then
        OutputMessage("MSG_SYS", GetFormatText("", nil, 255,255,0) .. szMsg, true)
    end
    -- ����UI
    if _C.uiBoard then
        local nPos = _C.uiBoard:scroll()
        _C.uiBoard:append(rec.html)
        if nPos == 100 or nPos == -1 then
            _C.uiBoard:scroll(100)
        end
    end
    if MY_ChatMonitor.bShowPreview then
        _C.ShowTip(rec.html)
    end
    --------------------------------------------------------------------------------------
    -- ��ʼ�����¼�����ݱ���
    -- ���»������� ��ϣ��
    table.insert(tRecords, rec)
    tRecords[rec.hash] = (tRecords[rec.hash] or 0) + 1
    -- ��֤��¼�Ƿ񳬹���������
    local nOverflowed = #tRecords - MY_ChatMonitor.nMaxRecord
    if nOverflowed > 0 then
        -- �����¼�б�
        for i = nOverflowed, 1, -1 do
            local hash = tRecords[1].hash
            if hash then
                tRecords[hash] = tRecords[hash] - 1
                if tRecords[hash] <= 0 then
                    tRecords[hash] = nil
                end
            end
            table.remove(tRecords, 1)
        end
        -- ����UI
        if _C.uiBoard then
            local nCopyLinkCount = 0
            _C.uiBoard:hdl(1):children():each(function(ui)
                local name = ui:name()
                if this:GetType() == "Text" and
                (name == 'timelink' or
                 name == 'copylink' or
                 name == 'copy') then
                    nCopyLinkCount = nCopyLinkCount + 1
                end
                if nCopyLinkCount > nOverflowed then
                    return 0
                end
                ui:remove()
            end)
        end
    end
end

_C.OnPanelActive = function(wnd)
    local ui = MY.UI(wnd)
    local w, h = ui:size()
    
    ui:append("Text", "Label_KeyWord"):find('#Label_KeyWord')
      :pos(22,15):size(100,25):text(_L['key words:'])
    
    ui:append("WndAutocomplete", "WndAutocomplete_KeyWord"):children('#WndAutocomplete_KeyWord')
      :pos(80,15):size(w-226,25):text(MY_ChatMonitor.szKeyWords)
      :change(function(raw, szText) MY_ChatMonitor.szKeyWords = szText end)
      :focus(function(self)
        local source = {}
        for _, szOpt in ipairs(MY.LoadLUAData(_C.szLuaData) or {}) do
            if type(szOpt) == "string" then
                table.insert(source, szOpt)
            end
        end
        self:autocomplete('option', 'source', source)
      end)
      :click(function(nButton, raw)
        if IsPopupMenuOpened() then
            MY.UI(raw):autocomplete('close')
        else
            MY.UI(raw):autocomplete('search', '')
        end
      end)
      -- :autocomplete('option', 'beforeSearch', function(wnd, option) end)
      :autocomplete('option', 'beforePopup', function(menu, wnd, option)
        if #menu > 0 then
            table.insert(menu, { bDevide = true })
        end
        table.insert(menu, { szOption = _L['add'], fnAction = function()
            local edit = ui:children('#WndAutocomplete_KeyWord')
            GetUserInput("", function(szVal)
                szVal = (string.gsub(szVal, "^%s*(.-)%s*$", "%1"))
                if szVal~="" then
                    local t = MY.LoadLUAData(_C.szLuaData) or {}
                    for i = #t, 1, -1 do
                        if t[i] == szVal then return end
                    end
                    table.insert(t, szVal)
                    MY.SaveLUAData(_C.szLuaData, t)
                end
            end, function() end, function() end, nil, edit:text() )
        end })
      end)
      :autocomplete('option', 'beforeDelete', function(szOption, fnDoDelete, option)
        local t = MY.LoadLUAData(_C.szLuaData) or {}
        for i = #t, 1, -1 do
            if t[i] == szOption then
                table.remove(t, i)
            end
        end
        MY.SaveLUAData(_C.szLuaData, t)
      end)

    ui:append("Image", "Image_Help"):find('#Image_Help')
      :image('UI/Image/UICommon/Commonpanel2.UITex',48)
      :pos(8,10):size(25,25)
      :hover(function(bIn) this:SetAlpha( (bIn and 255 ) or 180) end)
      :click(function(nButton)
        local szText = "<image>path=\"ui/Image/UICommon/Talk_Face.UITex\" frame=25 w=24 h=24</image> <text>text=" .. EncodeComponentsString(_L['CHAT_MONITOR_TIP']) .." font=207 </text>"
        local x, y = Cursor.GetPos()
        local w, h = this:GetSize()
        OutputTip(szText, 450, {x, y, w, h})
    end):alpha(180)
    
    ui:append("Image", "Image_Setting"):find('#Image_Setting'):pos(w-26,13):image('UI/Image/UICommon/Commonpanel.UITex',18):size(30,30):alpha(200):hover(function(bIn) this:SetAlpha((bIn and 255) or 200) end):click(function()
        PopupMenu((function()
            local t = {}
            for _, cg in ipairs(_C.tChannelGroups) do
                local _t = { szOption = cg.szCaption }
                if cg.tChannels[1] then
                    for _, szChannel in ipairs(cg.tChannels) do
                        table.insert(_t,{
                            szOption = g_tStrings.tChannelName[szChannel],
                            rgb = GetMsgFontColor(szChannel, true),
                            fnAction = function()
                                MY_ChatMonitor.tChannels[szChannel] = not MY_ChatMonitor.tChannels[szChannel]
                                _C.RegisterMsgMonitor()
                            end,
                            bCheck = true,
                            bChecked = MY_ChatMonitor.tChannels[szChannel]
                        })
                    end
                else
                    for szPrefix, tChannels in pairs(cg.tChannels) do
                        if #_t > 0 then
                            table.insert(_t,{ bDevide = true })
                        end
                        table.insert(_t,{
                            szOption = szPrefix,
                            bDisable = true,
                        })
                        for _, szChannel in ipairs(tChannels) do
                            table.insert(_t,{
                                szOption = g_tStrings.tChannelName[szChannel],
                                rgb = GetMsgFontColor(szChannel, true),
                                fnAction = function()
                                    MY_ChatMonitor.tChannels[szChannel] = not MY_ChatMonitor.tChannels[szChannel]
                                    _C.RegisterMsgMonitor()
                                end,
                                bCheck = true,
                                bChecked = MY_ChatMonitor.tChannels[szChannel]
                            })
                        end
                    end
                end
                table.insert(t, _t)
            end
            table.insert(t, { bDevide = true })
            table.insert(t,{
                szOption = _L['timestrap format'], {
                    szOption = "[hh:mm:ss]",
                    fnAction = function()
                        MY_ChatMonitor.szTimestrap = "[hh:mm:ss]"
                    end,
                    bCheck = true, bMCheck = true,
                    bChecked = MY_ChatMonitor.szTimestrap == "[hh:mm:ss]"
                }, {
                    szOption = "[MM/dd hh:mm:ss]",
                    fnAction = function()
                        MY_ChatMonitor.szTimestrap = "[MM/dd hh:mm:ss]"
                    end,
                    bCheck = true, bMCheck = true,
                    bChecked = MY_ChatMonitor.szTimestrap == "[MM/dd hh:mm:ss]"
                }, {
                    szOption = _L['custom'],
                    fnAction = function()
                        GetUserInput(_L["custom timestrap (eg:[yyyy/MM/dd_hh:mm:ss])"], function(szText)
        					MY_ChatMonitor.szTimestrap = szText
        				end, nil, nil, nil, MY_ChatMonitor.szTimestrap)
                    end,
                },
            })
            table.insert(t,{
                szOption = _L['max record count'],
                fnAction = function()
                    GetUserInputNumber(MY_ChatMonitor.nMaxRecord, 1000, nil, function(val)
                        MY_ChatMonitor.nMaxRecord = val or MY_ChatMonitor.nMaxRecord
                    end, nil, function() return not MY.IsPanelVisible() end)
                end,
            })
            table.insert(t,{
                szOption = _L['show message preview box'],
                fnAction = function()
                    MY_ChatMonitor.bShowPreview = not MY_ChatMonitor.bShowPreview
                end,
                bCheck = true,
                bChecked = MY_ChatMonitor.bShowPreview
            })
            table.insert(t,{
                szOption = _L['play new message alert sound'],
                fnAction = function()
                    MY_ChatMonitor.bPlaySound = not MY_ChatMonitor.bPlaySound
                end,
                bCheck = true,
                bChecked = MY_ChatMonitor.bPlaySound
            })
            table.insert(t,{
                szOption = _L['output to system channel'],
                fnAction = function()
                    MY_ChatMonitor.bRedirectSysChannel = not MY_ChatMonitor.bRedirectSysChannel
                end,
                bCheck = true,
                bChecked = MY_ChatMonitor.bRedirectSysChannel
            })
            table.insert(t,{
                szOption = _L['ignore same message'],
                fnAction = function()
                    MY_ChatMonitor.bIgnoreSame = not MY_ChatMonitor.bIgnoreSame
                end,
                bCheck = true,
                bChecked = MY_ChatMonitor.bIgnoreSame
            })
            if MY_Chat then
                table.insert(t,{
                    szOption = _L['hide blockwords'],
                    fnAction = function()
                        MY_ChatMonitor.bBlockWords = not MY_ChatMonitor.bBlockWords
                    end,
                    bCheck = true,
                    bChecked = MY_ChatMonitor.bBlockWords, {
                        szOption = _L['edit'],
                        fnAction = function()
                            MY.SwitchTab("MY_Chat_Filter")
                        end,
                    }
                })
            end
            table.insert(t, { bDevide = true })
            table.insert(t,{
                szOption = _L['regular expression'],
                fnAction = function()
                    if MY_ChatMonitor.bIsRegexp then
                        MY_ChatMonitor.bIsRegexp = not MY_ChatMonitor.bIsRegexp
                    else
                        MessageBox({
                            szName = "MY_ChatMonitor_Regexp",
                            szMessage = _L["Are you sure you want to turn on regex mode?\nRegex is something advanced, make sure you know what you are doing."],
                            {szOption = g_tStrings.STR_HOTKEY_SURE, fnAction = function() MY_ChatMonitor.bIsRegexp = not MY_ChatMonitor.bIsRegexp end},
                            {szOption = g_tStrings.STR_HOTKEY_CANCEL, fnAction = function() end},
                        })
                    end
                end,
                bCheck = true,
                bChecked = MY_ChatMonitor.bIsRegexp
            })
            return t
        end)())
    end)

    ui:append("WndButton", "Button_ChatMonitor_Switcher"):find('#Button_ChatMonitor_Switcher'):pos(w-136,15):width(50):text((MY_ChatMonitor.bCapture and _L['stop']) or _L['start']):click(function()
        if MY_ChatMonitor.bCapture then
            MY.UI(this):text(_L['start'])
            MY_ChatMonitor.bCapture = false
        else
            MY.UI(this):text(_L['stop'])
            MY_ChatMonitor.bCapture = true
        end
    end)
    
    ui:append("WndButton", "Button_Clear"):find('#Button_Clear'):pos(w-81,15):width(50):text(_L['clear']):click(function()
        MY_ChatMonitor.tRecords = {}
        _C.uiBoard:clear()
    end)
    
    _C.uiBoard = ui
      :append("WndScrollBox", "WndScrollBox_TalkList")
      :children('#WndScrollBox_TalkList')
      :handleStyle(3):pos(20,50):size(w-21, h - 70)
    
    local tRecords = MY_ChatMonitor.tRecords
    for i = 1, #tRecords, 1 do
        _C.uiBoard:append(tRecords[i].html)
    end
    _C.uiBoard:scroll(100)
    _C.ui = MY.UI(wnd)
    _C.Init()
end

_C.ShowTip = function(szMsg)
    if szMsg then
        _C.uiTipBoard:clear():append(szMsg)
    end
    _C.uiFrame:fadeTo(500, 255)
    if Station.GetMouseOverWindow() and
    Station.GetMouseOverWindow():GetRoot():GetName() == 'MY_ChatMonitor' then
        MY.DelayCall('MY_ChatMonitor_Hide', 5000)
    else
        MY.DelayCall('MY_ChatMonitor_Hide', 5000, function()
            _C.uiFrame:fadeOut(500)
        end)
    end
end

_C.Init = function()
    if _C.bInited then
        return
    end
    _C.bInited = true
    _C.RegisterMsgMonitor()

    -- create tip frame
    _C.uiFrame = MY.UI.CreateFrame('MY_ChatMonitor', {level = 'Topmost', empty = true})
      :size(250,150)
      :toggle(false)
      :onevent("UI_SCALED", function() -- �ƶ���ʾ��λ��
        _C.uiFrame:anchor(MY_ChatMonitor.anchor)
      end)
      :customMode(_L["chat monitor"], function()
        MY.DelayCall('MY_ChatMonitor_Hide')
        _C.uiFrame:show():alpha(255)
      end, function()
        MY_ChatMonitor.anchor = _C.uiFrame:anchor()
        _C.uiFrame:alpha(0):hide()
      end)
      :anchor(MY_ChatMonitor.anchor)
    -- init tip panel handle and bind animation function
    _C.uiTipBoard = _C.uiFrame
      :append("WndScrollBox", "WndScrollBox_TalkList")
      :children('#WndScrollBox_TalkList')
      :handleStyle(3):pos(0,0):size(250,150)
      :text(_L['welcome to use mingyi chat monitor.'])
      :click(function()
        MY.OpenPanel()
        MY.SwitchTab('ChatMonitor')
        _C.uiFrame:fadeOut(500)
      end)
      :hover(function(bIn)
        if bIn then
            MY.DelayCall('MY_ChatMonitor_Hide')
            _C.uiFrame:fadeIn(500)
        else
            MY.DelayCall('MY_ChatMonitor_Hide', function()
                _C.uiFrame:fadeOut(500)
            end, 5000)
        end
      end)
    -- init tip panel animate
    MY.DelayCall('MY_ChatMonitor_Hide', function()
        _C.uiFrame:fadeOut(500)
    end, 10000)
    -- show tip
    _C.ShowTip()
end
MY.RegisterInit('MY_CHATMONITOR', _C.Init)

_C.RegisterMsgMonitor = function()
    local t = {}
    for szChannel, bCapture in pairs(MY_ChatMonitor.tChannels) do
        if bCapture then table.insert(t, szChannel) end
    end
    UnRegisterMsgMonitor(_C.OnMsgArrive)
    RegisterMsgMonitor(_C.OnMsgArrive, t)
end

MY.Game.AddHotKey("MY_ChatMonitor_Hotkey", _L["chat monitor"],
    function()
        if MY_ChatMonitor.bCapture then
            MY.UI(MY.GetFrame()):find('#Button_ChatMonitor_Switcher'):text(_L['start'])
            MY_ChatMonitor.bCapture = false
        else
            MY.UI(MY.GetFrame()):find('#Button_ChatMonitor_Switcher'):text(_L['stop'])
            MY_ChatMonitor.bCapture = true
        end
    end
, nil)

MY.RegisterPanel( "ChatMonitor", _L["chat monitor"], _L['Chat'], "UI/Image/Minimap/Minimap.UITex|197", {255,127,0,200}, {
    OnPanelActive = _C.OnPanelActive,
    OnPanelDeactive = function()
        _C.uiBoard = nil
    end
})
