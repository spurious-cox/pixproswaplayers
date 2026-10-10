-- PixProSwapLayers 3.2.0 — exchange the stacking order of the selected layers
--
-- The first selected layer trades places with the last, the second with the
-- second to last. An odd layer in the middle has no partner and stays put.
-- Layers in different groups are handled: `index` counts within a layer's own
-- parent, so each move names that parent, and when the two layers do not share
-- one, the second move goes `before` the old position rather than `after`.
--
-- Fewer than two layers selected: it says so and finishes. It does not wait.
-- A dialog of this app's own takes the focus the moment it appears, so the
-- layers cannot be clicked; a notification instead is silent when
-- notifications are off; and an app left waiting swallows the next launch,
-- because macOS will not start a second copy of it.
--
-- One version number: this property is what the dialogs show, and build.sh
-- reads it for the bundle, so the two cannot disagree.

property scriptVersion : "3.3.2"
property kPixIDs : {"com.apple.pixelmator", "com.pixelmatorteam.pixelmator.x"}
-- Set by pixTarget() before anything talks to Pixelmator.
property pixApp : ""
-- Update check, the same in every PixPro app: asks GitHub for the newest
-- release at most once a day, gives up after three seconds, says nothing when
-- this build is current or the network is away, and otherwise adds
-- "Update available" to what the app already shows. It never downloads or
-- replaces anything.
property kSlug : "pixproswaplayers"
property kDefaults : "$HOME/.pixproswaplayers_defaults"

on versionParts(v)
	set out to {}
	set AppleScript's text item delimiters to "."
	set pieces to text items of v
	set AppleScript's text item delimiters to ""
	repeat with piece in pieces
		set digits to ""
		repeat with c in (characters of (piece as text))
			if c is in "0123456789" then set digits to digits & c
		end repeat
		if digits is "" then set digits to "0"
		set end of out to digits as integer
	end repeat
	return out
end versionParts

on isNewer(tag, mine)
	-- Compared as integers, so 3.10.0 comes out above 3.9.0 rather than below.
	set a to my versionParts(tag)
	set b to my versionParts(mine)
	repeat with i from 1 to 3
		set x to 0
		set y to 0
		if i ≤ (count a) then set x to item i of a
		if i ≤ (count b) then set y to item i of b
		if x > y then return true
		if x < y then return false
	end repeat
	return false
end isNewer

on latestTag()
	set today to do shell script "/bin/date +%Y-%m-%d"
	set lastDay to ""
	try
		set lastDay to do shell script "defaults read " & kDefaults & " updateCheckedOn 2>/dev/null"
	end try
	if lastDay is today then
		try
			return do shell script "defaults read " & kDefaults & " updateLatestTag 2>/dev/null"
		end try
		return ""
	end if
	try
		set tag to do shell script "/usr/bin/curl -sL --max-time 3 -H \"Accept: application/vnd.github+json\" https://api.github.com/repos/spurious-cox/" & kSlug & "/releases/latest | /usr/bin/grep -o '\"tag_name\": *\"[^\"]*\"' | /usr/bin/head -1 | /usr/bin/cut -d'\"' -f4"
		do shell script "defaults write " & kDefaults & " updateLatestTag " & quoted form of tag
		do shell script "defaults write " & kDefaults & " updateCheckedOn " & quoted form of today
		return tag
	on error
		return ""
	end try
end latestTag

on updateNotice(mine)
	set tag to my latestTag()
	if tag is "" then return ""
	if not (my isNewer(tag, mine)) then return ""
	set t to tag
	if t starts with "v" then set t to text 2 thru -1 of t
	return return & return & "Update available: " & t & "  —  brew upgrade --cask " & kSlug
end updateNotice


on pixTarget()
	set rawPaths to {}
	try
		set psOut to do shell script "/bin/ps -Axo args= | /usr/bin/grep '/Contents/MacOS/Pixelmator' | /usr/bin/grep -v grep | /usr/bin/sed 's|/Contents/MacOS/.*||' | /usr/bin/sort -u"
		-- `do shell script` separates lines with RETURN, not linefeed. Split on
		-- the wrong one and every path arrives glued into a single string.
		set AppleScript's text item delimiters to return
		set rawPaths to text items of psOut
		set AppleScript's text item delimiters to ""
	end try
	
	-- Keep only genuine Pixelmator Pro builds, identified by the bundle id in
	-- each app's OWN Info.plist. Nothing here depends on what the app is
	-- called or where it lives, so this works on any Mac: renamed bundles,
	-- App Store or Setapp copies, apps in ~/Applications, all fine. It also
	-- excludes the classic Pixelmator (com.pixelmatorteam.pixelmator), whose
	-- dictionary is different and which would fail halfway through.
	set candidates to {}
	repeat with rp in rawPaths
		set p to rp as text
		if p is not "" then
			try
				set theID to do shell script "/usr/bin/defaults read " & quoted form of (p & "/Contents/Info") & " CFBundleIdentifier"
				if theID is in kPixIDs then set end of candidates to p
			end try
		end if
	end repeat
	if candidates is {} then return ""
	
	-- Which of them, if any, is frontmost. The frontmost process's pid maps
	-- back to its bundle path through ps.
	set frontPath to ""
	try
		-- Bounded: asking System Events which app is frontmost needs Automation
		-- permission, and on an app's FIRST run that call sits there waiting
		-- for a consent prompt. If the prompt does not appear — and it may
		-- not, for a freshly built applet — the script hangs with no window
		-- and nothing to click. Five seconds, then carry on without it: the
		-- frontmost check only orders the candidates, it does not find them.
		with timeout of 5 seconds
			tell application "System Events"
				set fpid to my topPixelmatorPID(unix id of (first application process whose frontmost is true))
			end tell
		end timeout
		set frontPath to do shell script "/bin/ps -p " & fpid & " -o args= | /usr/bin/sed 's|/Contents/MacOS/.*||'"
	end try
	
	set ordered to {}
	repeat with c in candidates
		set cc to c as text
		if cc is equal to frontPath then set end of ordered to cc
	end repeat
	repeat with c in candidates
		set cc to c as text
		if cc is not equal to frontPath then set end of ordered to cc
	end repeat
	
	repeat with c in ordered
		set cc to c as text
		try
			using terms from application "Pixelmator Pro Creator Studio"
				tell application cc
					if (count of documents) > 0 then return cc
				end tell
			end using terms from
		end try
	end repeat
	return item 1 of ordered
end pixTarget

on dialogTitle()
	return "PixProSwapLayers v" & scriptVersion
end dialogTitle

on bringForward()
	try
		tell me to activate
	end try
end bringForward

on alertUser(msg)
	my bringForward()
	display dialog msg buttons {"OK"} default button "OK" with title my dialogTitle()
end alertUser

on run
	set pixApp to pixTarget()
	if pixApp is "" then
		my alertUser("Pixelmator Pro is not running. Open Pixelmator Pro and a document, select the layers to swap, and try again.")
		return
	end if

	using terms from application "Pixelmator Pro"
		tell application pixApp
			if (count of documents) is 0 then
				my alertUser("No document is open in Pixelmator Pro.")
				return
			end if

			tell front document
				-- Wait rather than refuse. Launching this app takes the focus
				-- off Pixelmator, and a selection made before that is not
				-- always still there when the script reads it — so the dialog
				-- stays up while the layers are selected, and reads the
				-- selection again when Swap is clicked.
				set chosen to selected layers
				set pairCount to (count of chosen)
				-- NO DIALOG while we wait. A dialog put up by this app takes
				-- the focus the moment it appears, however carefully
				-- Pixelmator is activated first, and the layers cannot be
				-- clicked while it is there — the user could only cancel.
				-- Instead Pixelmator is brought forward and the selection is
				-- watched, so the layers can be picked normally and the swap
				-- happens as soon as two of them are.
				-- With fewer than two layers selected it says so and stops.
				--
				-- WAITING WAS TRIED THREE TIMES AND DOES NOT WORK HERE. A
				-- dialog of this app's own takes the focus the moment it
				-- appears, so the layers cannot be clicked; a notification
				-- instead is silent when notifications are switched off, and
				-- the app then sits there invisibly; and an app that sits
				-- there swallows the NEXT launch, because macOS will not start
				-- a second copy — so clicking it again appears to do nothing
				-- at all. Finishing immediately is the only behaviour that is
				-- always visible and always leaves a clean slate.
				if pairCount < 2 then
					my alertUser("Select two or more layers in Pixelmator Pro, then run PixProSwapLayers again." & return & return & "Selected now: " & (pairCount as text))
					return
				end if

				-- Outermost pair inwards: first with last, second with second
				-- to last. An odd layer in the middle has no partner and stays
				-- where it is.
				repeat with idxA from 1 to (pairCount div 2)
					set idxB to pairCount - idxA + 1

					-- Whichever sits LOWER in the stack is treated as A, so
					-- the two moves below always run in the same direction.
					set swapA to item idxA of chosen
					set swapB to item idxB of chosen
					if (index of swapA) > (index of swapB) then
						set swapA to item idxB of chosen
						set swapB to item idxA of chosen
					end if

					set oldA to index of swapA
					set oldB to index of swapB
					set parentA to parent of swapA
					set parentB to parent of swapB

					-- `index` counts within the layer's own parent, so a move
					-- has to name that parent whenever the layer is in a group.
					if parentA is missing value then
						move swapB to after layer oldA
					else
						move swapB to after layer oldA in parentA
					end if

					-- Moving B has already shifted A when the two share a
					-- parent; when they do not, A has to land before the old
					-- position rather than after it.
					set crossesGroups to (parentA is not parentB)
					if parentB is missing value then
						if crossesGroups then
							move swapA to before layer oldB
						else
							move swapA to after layer oldB
						end if
					else
						if crossesGroups then
							move swapA to before layer oldB in parentB
						else
							move swapA to after layer oldB in parentB
						end if
					end if
				end repeat
			end tell
		end tell
	end using terms from

	-- This app has no dialog of its own to carry a notice, so a newer release
	-- is reported as a notification — and only when there IS one. Nothing is
	-- shown, and nothing is delayed beyond the three-second cap, otherwise.
	if my updateNotice(scriptVersion) is not "" then
		display notification "Update available — brew upgrade --cask " & kSlug ¬
			with title "PixProSwapLayers " & scriptVersion
	end if
end run


-- ============================================================
-- TOPMOST PIXELMATOR (v3.3.2, 2026-10-10)
-- ============================================================
-- Which Pixelmator Pro the person is looking at. "Frontmost application" is
-- no help when this applet was started from Stache, Flache or the Dock,
-- because the applet itself is then frontmost. The window list is ordered
-- front to back, so the first Pixelmator Pro window in it belongs to the build
-- on top. Visible windows are tried first, then all windows (a build on
-- another Space). Reading owner pid, name and size needs no Screen Recording
-- permission. Falls back to `fallback` when nothing is found.
on topPixelmatorPID(fallback)
	set js to "ObjC.import(\"CoreGraphics\");" & ¬
		"function top(o){var l=ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(o,0)));" & ¬
		"for(var i=0;i<l.length;i++){var w=l[i];" & ¬
		"if(w.kCGWindowOwnerName==\"Pixelmator Pro\"&&w.kCGWindowLayer==0&&w.kCGWindowBounds.Height>100)return w.kCGWindowOwnerPID;}" & ¬
		"return \"\";}" & ¬
		"var r=top(17);if(r===\"\")r=top(16);r"
	try
		set r to do shell script "/usr/bin/osascript -l JavaScript -e " & quoted form of js
		if r is not "" then return r as integer
	end try
	return fallback
end topPixelmatorPID
