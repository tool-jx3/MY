--
-- �����¼
-- ��¼�Ŷ�/����/���/���� ���պ��ѯ
-- ���ߣ���һ�� @ tinymins
-- ��վ��ZhaiYiMing.CoM
--

-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local ssub, slen, schar, srep, sbyte, sformat, sgsub =
	  string.sub, string.len, string.char, string.rep, string.byte, string.format, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local floor, mmin, mmax, mceil = math.floor, math.min, math.max, math.ceil
local GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID = GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID
local setmetatable = setmetatable

local _L  = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. "MY_ChatLog/lang/")
local _C  = {}
local Log = {}
local XML_LINE_BREAKER = XML_LINE_BREAKER
local tinsert, tconcat, tremove = table.insert, table.concat, table.remove
MY_ChatLog = MY_ChatLog or {}
MY_ChatLog.szActiveChannel         = "MSG_WHISPER" -- ��ǰ����ı�ǩҳ
MY_ChatLog.bIgnoreTongOnlineMsg    = true -- �������֪ͨ
MY_ChatLog.bIgnoreTongMemberLogMsg = true -- ����Ա����������ʾ
MY_ChatLog.bBlockWords             = true -- ����¼���ιؼ���
RegisterCustomData('MY_ChatLog.bBlockWords')
RegisterCustomData('MY_ChatLog.bIgnoreTongOnlineMsg')
RegisterCustomData('MY_ChatLog.bIgnoreTongMemberLogMsg')

------------------------------------------------------------------------------------------------------
-- ���ݲɼ�
------------------------------------------------------------------------------------------------------
_C.TongOnlineMsg	   = '^' .. MY.String.PatternEscape(g_tStrings.STR_TALK_HEAD_TONG .. g_tStrings.STR_GUILD_ONLINE_MSG)
_C.TongMemberLoginMsg  = '^' .. MY.String.PatternEscape(g_tStrings.STR_GUILD_MEMBER_LOGIN):gsub('<link 0>', '.-') .. '$'
_C.TongMemberLogoutMsg = '^' .. MY.String.PatternEscape(g_tStrings.STR_GUILD_MEMBER_LOGOUT):gsub('<link 0>', '.-') .. '$'

function _C.OnMsg(szMsg, szChannel, nFont, bRich, r, g, b)
	local szText = szMsg
	if bRich then
		szText = GetPureText(szMsg)
	else
		szMsg = GetFormatText(szMsg, nil, r, g, b)
	end
	if MY_ChatLog.bBlockWords
	and MY_Chat and MY_Chat.MatchBlockWord
	and MY_Chat.MatchBlockWord(szText, szChannel, false) then
		return
	end
	-- filters
	if szChannel == "MSG_GUILD" then
		if MY_ChatLog.bIgnoreTongOnlineMsg and szText:find(_C.TongOnlineMsg) then
			return
		end
		if MY_ChatLog.bIgnoreTongMemberLogMsg and (
			szText:find(_C.TongMemberLoginMsg) or szText:find(_C.TongMemberLogoutMsg)
		) then
			return
		end
	end
	-- generate rec
	szMsg = MY.Chat.GetTimeLinkText({r=r, g=g, b=b, f=nFont, s='[hh:mm:ss]'}) .. szMsg
	-- save and draw rec
	_C.AppendLog(szChannel, _C.GetCurrentDate(), szMsg)
	_C.UiAppendLog(szChannel, szMsg)
end

function _C.OnTongMsg(szMsg, nFont, bRich, r, g, b)
	_C.OnMsg(szMsg, 'MSG_GUILD', nFont, bRich, r, g, b)
end
function _C.OnWisperMsg(szMsg, nFont, bRich, r, g, b)
	_C.OnMsg(szMsg, 'MSG_WHISPER', nFont, bRich, r, g, b)
end
function _C.OnRaidMsg(szMsg, nFont, bRich, r, g, b)
	_C.OnMsg(szMsg, 'MSG_TEAM', nFont, bRich, r, g, b)
end
function _C.OnFriendMsg(szMsg, nFont, bRich, r, g, b)
	_C.OnMsg(szMsg, 'MSG_FRIEND', nFont, bRich, r, g, b)
end
function _C.OnIdentityMsg(szMsg, nFont, bRich, r, g, b)
	_C.OnMsg(szMsg, 'MSG_IDENTITY', nFont, bRich, r, g, b)
end

MY.RegisterInit("MY_CHATLOG_REGMSG", function()
	MY.RegisterMsgMonitor('MY_ChatLog_Tong'  , _C.OnTongMsg  , { 'MSG_GUILD', 'MSG_GUILD_ALLIANCE' })
	MY.RegisterMsgMonitor('MY_ChatLog_Wisper', _C.OnWisperMsg, { 'MSG_WHISPER' })
	MY.RegisterMsgMonitor('MY_ChatLog_Raid'  , _C.OnRaidMsg  , { 'MSG_TEAM', 'MSG_PARTY', 'MSG_GROUP' })
	MY.RegisterMsgMonitor('MY_ChatLog_Friend', _C.OnFriendMsg, { 'MSG_FRIEND' })
	MY.RegisterMsgMonitor('MY_ChatLog_Identity', _C.OnIdentityMsg, { 'MSG_IDENTITY' })
end)

------------------------------------------------------------------------------------------------------
-- ���ݴ�ȡ
------------------------------------------------------------------------------------------------------
--[[
	Log = {
		MSG_WHISPER = {
			DateList = { 20150214, 20150215 }
			DateIndex = { [20150214] = 1, [20150215] = 2 }
			[20150214] = { <szMsg>, <szMsg>, ... },
			[20150215] = { <szMsg>, <szMsg>, ... },
			...
		},
		...
	}
]]
local DATA_PATH = 'userdata/CHAT_LOG/$uid/%s/%s.$lang.jx3dat'

_C.tModifiedLog = {}
function _C.GetCurrentDate()
	return tonumber(MY.Sys.FormatTime("yyyyMMdd", GetCurrentTime()))
end

function _C.RebuildDateList(tChannels, nScanDays)
	_C.UnloadLog()
	local nDailySec = 24 * 3600
	for _, szChannel in ipairs(tChannels) do
		Log[szChannel] = { DateList = {} }
		local dwEndedTime = GetCurrentTime()
		local dwStartTime = GetCurrentTime() - nScanDays * nDailySec
		local tDateList  = Log[szChannel].DateList
		for dwTime = dwStartTime, dwEndedTime, nDailySec do
			local szDate = MY.Sys.FormatTime("yyyyMMdd", dwTime)
			if IsFileExist(MY.GetLUADataPath(DATA_PATH:format(szChannel, szDate))) then
				tinsert(tDateList, szDate)
				_C.tModifiedLog[szChannel] = { DateList = true }
			end
		end
	end
	_C.UnloadLog()
end

function _C.GetDateList(szChannel)
	if not Log[szChannel] then
		Log[szChannel] = {}
		Log[szChannel].DateList = MY.LoadLUAData(DATA_PATH:format(szChannel, 'DateList')) or {}
		Log[szChannel].DateIndex = {}
		for i, dwDate in ipairs(Log[szChannel].DateList) do
			Log[szChannel].DateIndex[dwDate] = i
		end
	end
	return Log[szChannel].DateList, Log[szChannel].DateIndex
end

function _C.GetLog(szChannel, dwDate)
	_C.GetDateList(szChannel)
	if not Log[szChannel][dwDate] then
		Log[szChannel][dwDate] = MY.LoadLUAData(DATA_PATH:format(szChannel, dwDate)) or {}
	end
	return Log[szChannel][dwDate]
end

function _C.AppendLog(szChannel, dwDate, szMsg)
	local log = _C.GetLog(szChannel, dwDate)
	tinsert(log, szMsg)
	-- mark as modified
	if not _C.tModifiedLog[szChannel] then
		_C.tModifiedLog[szChannel] = {}
	end
	_C.tModifiedLog[szChannel][dwDate] = true
	-- append datelist
	local DateList, DateIndex = _C.GetDateList(szChannel)
	if not DateIndex[dwDate] then
		tinsert(DateList, dwDate)
		DateIndex[dwDate] = #DateList
		_C.tModifiedLog[szChannel]['DateList'] = true
	end
	MY.DelayCall("MY_ChatLog",  _C.SaveLog, 30000)
end

function _C.SaveLog()
	for szChannel, tDate in pairs(_C.tModifiedLog) do
		for dwDate, _ in pairs(tDate) do
			if not empty(Log[szChannel][dwDate]) then
				MY.SaveLUAData(DATA_PATH:format(szChannel, dwDate), Log[szChannel][dwDate], nil, true)
			end
		end
	end
	_C.tModifiedLog = {}
end

function _C.UnloadLog()
	_C.SaveLog()
	Log = {}
end
MY.RegisterExit(_C.UnloadLog)

local function htmlEncode(html)
	return html
	:gsub("&", "&amp;")
	:gsub(" ", "&ensp;")
	:gsub("<", "&lt;")
	:gsub(">", "&gt;")
	:gsub('"', "&quot;")
	:gsub("\n", "<br>")
end

local function getHeader()
	local szHeader = [[<!DOCTYPE html>
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=]]
	.. ((MY.GetLang() == "zhcn" and "GBK") or "UTF-8") .. [[" />
<style>
*{font-size: 12px}
a{line-height: 16px}
input, button, select, textarea {outline: none}
body{background-color: #000; margin: 8px 8px 45px 8px}
#browserWarning{background-color: #f00; font-weight: 800; color:#fff; padding: 8px; position: fixed; opacity: 0.92; top: 0; left: 0; right: 0}
.channel{color: #fff; font-weight: 800; font-size: 32px; padding: 0; margin: 30px 0 0 0}
.date{color: #fff; font-weight: 800; font-size: 24px; padding: 0; margin: 0}
a.content{font-family: cursive}
span.emotion_44{width:21px; height: 21px; display: inline-block; background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAVCAYAAACpF6WWAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAO/SURBVDhPnZT7U4xRGMfff4GftEVKYsLutkVETKmsdrtY9QMNuTRDpVZS2Fw2utjcL1NSYaaUa5gRFSK5mzFukzHGYAbjOmTC7tv79vWcs2+bS7k9M985u+c953PO85zneYS+zBQThYChKvj7ejg1zDnqfN1hipkKZdnfmXFKKLRD3aHXecMyPQh1q+PRVr4Qj2qycKZkAfLmRyJitA80tCaa1irb+rZR3m4I9huIgsQQvKxKxZemXEgNuZAvrIPcWoSuqzbYH5bhcZMV6fHjETjcA6OGuPUNHuk9AJM1g3E4IxId9TnwcuvHJV0phHQuD9L5fODFPtf8mwcV2JIVg4kab6h9VL+Co/VhGOOrQlnSBHQcWeyE3SqG1JKHzoaVkC4WQr68HniyGUAb6QFf86FtC0qzTRhL3kVPCfsRrKGTUsNH4lX5PDiOLoZ0yQrpzCoOlW9uoLGAu4/2cgK2kC6QGiG9rsCr5gKkm8ZBTTFWcIIQH2dAyHAV7q+d5nLNJVV/Psq3NkO+RNC3lb+s8VHWBNFtE4jFJGgolsmhfnheZKTTfzS2WL6/3XlTcr/r3iYC71S+Oo2teXfdhjlTAzDCawCXwNJnx8xgvC9Jgrg7EfZ98yAeSoGjLt3p+lkrZHp1+cp6GosJbkPXnXwuudWKLjpUvJiPvctMPM2YBH9K5pZsPeyls2HfkwzHQTPE49nobFrNX12+pgC/1zUGL+r5T6G5uyfNVSgcejs3CvYSgu4laFUKxBM5Lih3/Xtgb2otxNOaJdBR1TFxaIM5nG6ahK9lc+HYnwbxSCbE+hWQmtf+GcpCQ/FuLp7dc9MAHzdYo3X4vG0m7LuSYK+cD8eBDIinLehsZGn1E5QgbI6L8pd707gS62ZNhD+xmARTrAF69SA8sSX0hKA6tee2lJ+uh6L4MggrCHYgP5QOf1ebAUPgEGo0UVw8V1kGbEoYg090WwcVAH+wbvApBawAxZPLac7CH1Oi2H+py8LGWZN4E+KwbouibhOh8UR9Wjjat82Ao8IJ7jyYDrF6AaRTOUplkavHsyAezaRvZnRUL8KxpQZM8POAobeOFUClatB5oSY5BB+2Unx3z4FtSZyrcrply4ylmC/CRwoVaz562qP+XafS0MfgYSqsMGjxzGbiEPshCkMtpVkNSzUzn3tJYcqbFohJIzzA+oayvW8zUsdiVRHq5w6LUYvalDDcsBhxb00c6s2RyE8Igl7ryWPYq8u/s+nUGNTUF/xpM8tlLvqtJW9MscoL/6v9P1QQvgHonm5Hx/sAiwAAAABJRU5ErkJggg==")}
#controls{background-color: #fff; height: 25px; position: fixed; opacity: 0.92; bottom: 0; left: 0; right: 0}
#mosaics{width: 200px;height: 20px}
]]

	if MY_Farbnamen and MY_Farbnamen.GetForceRgb then
		for k, v in pairs(g_tStrings.tForceTitle) do
			szHeader = szHeader .. (".force-%s{color:#%02X%02X%02X}"):format(k, unpack(MY_Farbnamen.GetForceRgb(k)))
		end
	end

	szHeader = szHeader .. [[
</style></head>
<body>
<div id="browserWarning">Please allow running JavaScript on this page!</div>
<div id="controls" style="display:none">
	<input type="range" id="mosaics" min="0" max="200" value="0">
	<script type="text/javascript">
	(function() {
		var timerid, blurRadius;
		var setMosaicHandler = function() {
			var filter = "blur(" + blurRadius + ")";console.log(filter);
			var eles = document.getElementsByClassName("namelink");
			for(i = eles.length - 1; i >= 0; i--) {
				eles[i].style["filter"] = filter;
				eles[i].style["-o-filter"] = filter;
				eles[i].style["-ms-filter"] = filter;
				eles[i].style["-moz-filter"] = filter;
				eles[i].style["-webkit-filter"] = filter;
			}
			timerid = null;
		}
		var setMosaic = function(radius) {
			if (timerid)
				clearTimeout(timerid);
			blurRadius = radius;
			timerid = setTimeout(setMosaicHandler, 50);
		}
		document.getElementById("mosaics").oninput = function() {
			setMosaic((this.value / 100 + 0.5) + "px");
		}
	})();
	</script>
</div>
<script type="text/javascript">
	(function () {
		var Sys = {};
		var ua = navigator.userAgent.toLowerCase();
		var s;
		(s = ua.match(/rv:([\d.]+)\) like gecko/)) ? Sys.ie = s[1] :
		(s = ua.match(/msie ([\d.]+)/)) ? Sys.ie = s[1] :
		(s = ua.match(/firefox\/([\d.]+)/)) ? Sys.firefox = s[1] :
		(s = ua.match(/chrome\/([\d.]+)/)) ? Sys.chrome = s[1] :
		(s = ua.match(/opera.([\d.]+)/)) ? Sys.opera = s[1] :
		(s = ua.match(/version\/([\d.]+).*safari/)) ? Sys.safari = s[1] : 0;

		// if (Sys.ie) document.write('IE: ' + Sys.ie);
		// if (Sys.firefox) document.write('Firefox: ' + Sys.firefox);
		// if (Sys.chrome) document.write('Chrome: ' + Sys.chrome);
		// if (Sys.opera) document.write('Opera: ' + Sys.opera);
		// if (Sys.safari) document.write('Safari: ' + Sys.safari);

		if (!Sys.chrome && !Sys.firefox) {
			document.getElementById("browserWarning").innerHTML = "<a>WARNING: Please use </a><a href='http://www.google.cn/chrome/browser/desktop/index.html' style='color: yellow;'>Chrome</a></a> to browse this page!!!</a>";
		} else {
			document.getElementById("controls").style["display"] = null;
			document.getElementById("browserWarning").style["display"] = "none";
		}
	})();
</script>
<div>
<a style="color: #fff;margin: 0 10px">]] .. GetClientPlayer().szName .. " @ " .. MY.GetServer() ..
" Exported at " .. MY.FormatTime("yyyyMMdd hh:mm:ss", GetCurrentTime()) .. "</a><hr />"

	return szHeader
end

local function getFooter()
	return [[
</div>
</body>
</html>]]
end

local function getChannelTitle(szChannel)
	return [[<p class="channel">]] .. (g_tStrings.tChannelName[szChannel] or "") .. [[</p><hr />]]
end

local function getDateTitle(szDate)
	return [[<p class="date">]] .. (szDate or "") .. [[</p>]]
end

local function convertXml2Html(szXml)
	local aXml = MY.Xml.Decode(szXml)
	local t = {}
	if aXml then
		local text, name
		for _, xml in ipairs(aXml) do
			text = xml[''].text
			name = xml[''].name
			if text then
				local force
				text = htmlEncode(text)
				tinsert(t, '<a')
				if name and name:sub(1, 9) == "namelink_" then
					tinsert(t, ' class="namelink')
					if MY_Farbnamen and MY_Farbnamen.Get then
						local info = MY_Farbnamen.Get((text:gsub("[%[%]]", "")))
						if info then
							force = info.dwForceID
							tinsert(t, ' force-')
							tinsert(t, info.dwForceID)
						end
					end
					tinsert(t, '"')
				end
				if not force and xml[''].r and xml[''].g and xml[''].b then
					tinsert(t, (' style="color:#%02X%02X%02X"'):format(xml[''].r, xml[''].g, xml[''].b))
				end
				tinsert(t, '>')
				tinsert(t, text)
				tinsert(t, '</a>')
			elseif name and name:sub(1, 8) == "emotion_" then
				tinsert(t, '<span class="')
				tinsert(t, name)
				tinsert(t, '"></span>')
			end
		end
	end
	return tconcat(t)
end

local m_bExporting
function MY_ChatLog.ExportConfirm()
	if m_bExporting then
		return MY.Sysmsg({_L['Already exporting, please wait.']})
	end
	local ui = XGUI.CreateFrame("MY_ChatLog_Export", {
		simple = true, esc = true, close = true, w = 180,
		level = "Normal1", text = _L['export chatlog'], alpha = 200,
	})
	local btnSure
	local aChannels = {"MSG_GUILD", "MSG_WHISPER", "MSG_TEAM", "MSG_FRIEND", "MSG_IDENTITY"}
	local tChannels = {}
	local x, y = 10, 10
	for i, v in ipairs(aChannels) do
		ui:append("WndCheckBox", {
			x = x, y = y, w = 100,
			text = g_tStrings.tChannelName[v],
			checked = true,
			oncheck = function(checked)
				tChannels[v] = checked
				if checked then
					btnSure:enable(true)
				else
					btnSure:enable(false)
					for i,v in ipairs(aChannels) do
						if tChannels[v] then
							btnSure:enable(true)
							break
						end
					end
				end
			end,
		})
		y = y + 30
		tChannels[v] = true
	end
	y = y + 10

	btnSure = ui:append("WndButton", {
		x = x, y = y, w = 100,
		text = _L['export chatlog'],
		onclick = function()
			local chns = {}
			for i, v in ipairs(aChannels) do
				if tChannels[v] then
					table.insert(chns, v)
				end
			end
			MY_ChatLog.Export(
				MY.GetLUADataPath("export/ChatLog/$name@$server@" .. MY.FormatTime("yyyyMMddhhmmss") .. ".html"),
				chns, 10,
				function(title, progress)
					OutputMessage("MSG_ANNOUNCE_YELLOW", _L("Exporting chatlog: %s, %.2f%%.", title, progress * 100))
				end
			)
			ui:remove()
		end,
	}, true)
	y = y + 30
	ui:height(y + 50)
end

function MY_ChatLog.Export(szExportFile, aChannels, nPerSec, onProgress)
	local Log = _G.Log
	if m_bExporting then
		return MY.Sysmsg({_L['Already exporting, please wait.']})
	end
	if onProgress then
		onProgress(_L["preparing"], 0)
	end
	local status =  Log(szExportFile, getHeader(), "clear")
	if status ~= "SUCCEED" then
		return MY.Sysmsg({_L("Error: open file error %s [%s]", szExportFile, status)})
	end
	m_bExporting = true
	local szLastChannel, szLastDate
	local nChnIndex, nDateIndex, nOffset = 1, 1, 1
	local function Export()
		local szChannel = aChannels[nChnIndex]
		if not szChannel then
			m_bExporting = false
			Log(szExportFile, getFooter(), "close")
			if onProgress then
				onProgress(_L['Export succeed'], 1)
			end
			local szFile = GetRootPath() .. szExportFile:gsub("/", "\\")
			MY.Alert(_L('Chatlog export succeed, file saved as %s', szFile))
			MY.Sysmsg({_L('Chatlog export succeed, file saved as %s', szFile)})
			return 0
		end
		if szChannel ~= szLastChannel then
			szLastChannel = szChannel
			Log(szExportFile, getChannelTitle(szChannel))
		end
		local DateList, DateIndex = _C.GetDateList(szChannel)
		local szDate = DateList[nDateIndex]
		if not szDate then
			nDateIndex = 1
			nChnIndex = nChnIndex + 1
			return
		end
		if szDate ~= szLastDate then
			szLastDate = szDate
			Log(szExportFile, getDateTitle(szDate))
		end
		local aLog = _C.GetLog(szChannel, DateList[nDateIndex])
		local nUIndex = nOffset + nPerSec
		if nUIndex >= #aLog then
			nUIndex = #aLog
		end
		for i = nOffset, nUIndex do
			if onProgress then
				onProgress(g_tStrings.tChannelName[szChannel] .. " - " .. DateList[nDateIndex],
				(((i - 1) / #aLog + (nDateIndex - 1)) / #DateList + (nChnIndex - 1)) / #aChannels)
			end
			Log(szExportFile, convertXml2Html(aLog[i]))
		end
		if nUIndex >= #aLog then
			nOffset = 1
			nDateIndex = nDateIndex + 1
		else
			nOffset = nUIndex + 1
		end
	end
	MY.BreatheCall("MY_ChatLog_Export", Export)
end

------------------------------------------------------------------------------------------------------
-- �������
------------------------------------------------------------------------------------------------------
function _C.UiRedrawLog()
	if not _C.uiLog then
		return
	end
	_C.uiLog:clear()
	_C.nDrawDate  = nil
	_C.nDrawIndex = nil
	_C.UiDrawPrev(20)
	_C.uiLog:scroll(100)
	if MY_ChatMosaics and MY_ChatMosaics.Mosaics then
		MY_ChatMosaics.Mosaics(_C.uiLog:hdl(1):raw(1))
	end
end

-- ���ظ���
function _C.UiDrawPrev(nCount)
	if not _C.uiLog or _C.bUiDrawing == GetLogicFrameCount() then
		return
	end
	local h = _C.uiLog:hdl(1):raw(1)
	local szChannel = MY_ChatLog.szActiveChannel
	local DateList, DateIndex = _C.GetDateList(szChannel)
	if #DateList == 0 or -- û�м�¼���Լ���
	(_C.nDrawDate == DateList[1] and _C.nDrawIndex == 0) then -- û�и���ļ�¼���Լ���
		return
	elseif not _C.nDrawDate then -- ��û�м��ؽ���
		_C.nDrawDate = DateList[#DateList]
	end
	local nPos = 0
	local nLen = h:GetItemCount()
	-- ��ֹUI�ݹ���ѭ�� ��Դ��
	_C.bUiDrawing = GetLogicFrameCount()
	-- ���浱ǰ������λ��
	local _, nH = h:GetSize()
	local _, nOrginScrollH = h:GetAllItemSize()
	local nOrginScrollY = (nOrginScrollH - nH) * _C.uiLog:scroll() / 100
	-- ���������¼
	while nCount > 0 do
		-- ����ָ�����ڵļ�¼
		local log = _C.GetLog(szChannel, _C.nDrawDate)
		-- nDrawIndexΪ��������һ����ʼ����
		if not _C.nDrawIndex then
			_C.nDrawIndex = #log
		end
		-- ��������ڵļ�¼�Ƿ��㹻����ʣ�����������
		if _C.nDrawIndex > nCount then -- �㹻 ��ֱ�Ӽ���
			h:InsertItemFromString(0, false, tconcat(log, "", _C.nDrawIndex - nCount + 1, _C.nDrawIndex))
			_C.nDrawIndex = _C.nDrawIndex - nCount
			nCount = 0
		else -- ���� �������󽫼��ؽ���ָ����һ������
			h:InsertItemFromString(0, false, tconcat(log, "", 1, _C.nDrawIndex))
			h:InsertItemFromString(0, false, GetFormatText("========== " .. _C.nDrawDate .. " ==========\n")) -- ������������ڴ�
			-- �жϻ���û�м�¼���Լ���
			local nIndex = DateIndex[_C.nDrawDate]
			if nIndex == 1 then -- û�м�¼���Լ�����
				nCount = 0
				_C.nDrawIndex = 0
			else -- ���м�¼
				nCount = nCount - _C.nDrawIndex
				_C.nDrawDate = DateList[nIndex - 1]
				_C.nDrawIndex = nil
			end
		end
	end
	h:FormatAllItemPos()
	nLen = h:GetItemCount() - nLen
	MY_ChatMosaics.Mosaics(h, nPos, nLen)
	for i = 0, nLen do
		local hItem = h:Lookup(i)
		MY.Chat.RenderLink(hItem)
		if MY_Farbnamen and MY_Farbnamen.Render then
			MY_Farbnamen.Render(hItem)
		end
	end
	-- �ָ�֮ǰ������λ��
	if nOrginScrollY < 0 then -- ֮ǰû�й�����
		if _C.uiLog:scroll() >= 0 then -- �����й�����
			_C.uiLog:scroll(100)
		end
	else
		local _, nScrollH = h:GetAllItemSize()
		local nDeltaScrollH = nScrollH - nOrginScrollH
		_C.uiLog:scroll((nDeltaScrollH + nOrginScrollY) / (nScrollH - nH) * 100)
	end
	-- ��ֹUI�ݹ���ѭ�� ��Դ�����
	_C.bUiDrawing = nil
end

function _C.UiAppendLog(szChannel, szMsg)
	if not (_C.uiLog and szChannel == MY_ChatLog.szActiveChannel) then
		return
	end
	local bBottom = _C.uiLog:scroll() == 100
	if MY_ChatMosaics then
		local h = _C.uiLog:hdl(1):raw(1)
		local nCount
		if h then
			nCount = h:GetItemCount()
		end
		_C.uiLog:append(szMsg)
		if nCount then
			MY_ChatMosaics.Mosaics(h, nCount)
			for i = nCount, h:GetItemCount() - 1 do
				local hItem = h:Lookup(i)
				MY.Chat.RenderLink(hItem)
				if MY_Farbnamen and MY_Farbnamen.Render then
					MY_Farbnamen.Render(hItem)
				end
			end
		end
	else
		_C.uiLog:append(szMsg)
	end
	if bBottom then
		_C.uiLog:scroll(100)
	end
end

function _C.OnPanelActive(wnd)
	local ui = MY.UI(wnd)
	local w, h = ui:size()
	local x, y = 20, 10

	_C.uiLog = ui:append("WndScrollBox", "WndScrollBox_Log", {
		x = 20, y = 35, w = w - 21, h = h - 40, handlestyle = 3,
		onscroll = function(nScrollPercent, nScrollDistance)
			if nScrollPercent == 0 -- ��ǰ������λ��Ϊ0
			or (nScrollPercent == -1 and nScrollDistance == -1) then -- ��û�й���������������Ϲ���
				_C.UiDrawPrev(20)
			end
		end,
	}):children('#WndScrollBox_Log')

	for i, szChannel in ipairs({
		'MSG_GUILD'  ,
		'MSG_WHISPER',
		'MSG_TEAM'   ,
		'MSG_FRIEND' ,
		'MSG_IDENTITY',
	}) do
		ui:append('WndRadioBox', 'RadioBox_' .. szChannel):children('#RadioBox_' .. szChannel)
		  :pos(x + (i - 1) * 100, y):width(90)
		  :group("default")
		  :text(g_tStrings.tChannelName[szChannel] or '')
		  :check(function(bChecked)
		  	if bChecked then
		  		MY_ChatLog.szActiveChannel = szChannel
		  	end
		  	_C.UiRedrawLog()
		  end)
		  :check(MY_ChatLog.szActiveChannel == szChannel)
	end

	ui:append("Image", "Image_Setting"):item('#Image_Setting')
	  :pos(w - 26, y - 6):size(30, 30):alpha(200)
	  :image('UI/Image/UICommon/Commonpanel.UITex',18)
	  :hover(function(bIn) this:SetAlpha((bIn and 255) or 200) end)
	  :click(function()
	  	PopupMenu((function()
	  		local t = {}
	  		table.insert(t, {
	  			szOption = _L['filter tong member log message'],
	  			bCheck = true, bChecked = MY_ChatLog.bIgnoreTongMemberLogMsg,
	  			fnAction = function()
	  				MY_ChatLog.bIgnoreTongMemberLogMsg = not MY_ChatLog.bIgnoreTongMemberLogMsg
	  			end,
	  		})
	  		table.insert(t, {
	  			szOption = _L['filter tong online message'],
	  			bCheck = true, bChecked = MY_ChatLog.bIgnoreTongOnlineMsg,
	  			fnAction = function()
	  				MY_ChatLog.bIgnoreTongOnlineMsg = not MY_ChatLog.bIgnoreTongOnlineMsg
	  			end,
	  		})
	  		table.insert(t, {
	  			szOption = _L['rebuild date list'],
	  			fnAction = function()
	  				_C.RebuildDateList({
	  					"MSG_GUILD", "MSG_WHISPER", "MSG_TEAM", "MSG_FRIEND", "MSG_IDENTITY"
	  				}, (GetCurrentTime() - 1388505600) / 60 / 60 / 24)
	  				_C.UiRedrawLog()
	  			end,
	  		})
	  		table.insert(t, {
	  			szOption = _L['export chatlog'],
	  			fnAction = function()
					MY_ChatLog.ExportConfirm()
	  			end,
	  		})
            if MY_Chat then
                table.insert(t,{
                    szOption = _L['hide blockwords'],
                    fnAction = function()
                        MY_ChatLog.bBlockWords = not MY_ChatLog.bBlockWords
                    end,
                    bCheck = true,
                    bChecked = MY_ChatLog.bBlockWords, {
                        szOption = _L['edit'],
                        fnAction = function()
                            MY.SwitchTab("MY_Chat_Filter")
                        end,
                    }
                })
            end
	  		return t
	  	end)())
	end)

end

MY.RegisterPanel( "ChatLog", _L["chat log"], _L['Chat'], "ui/Image/button/SystemButton.UITex|43", {255,127,0,200}, {
	OnPanelActive = _C.OnPanelActive,
	OnPanelDeactive = function()
		_C.uiLog = nil
	end
})
