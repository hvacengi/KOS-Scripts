@LAZYGLOBAL off.

function libmath_def {
	return true.
}

global libmath_debug is false.

global PI is Constant():PI.
global BaseE is Constant():E.

global oneHour is 60 * 60.
global sixHours is 6 * oneHour.
global sixDays is 6 * sixHours.

// Set up any global defaults for environment settings
set steeringmanager:maxstoppingtime to 5. // steer faster

function sign {
	parameter number.
	if number < 0 return -1.
	return 1.
}

function quadratic {
	parameter a, b, c.
	return list(quadraticPlus(a, b, c), quadraticMinus(a, b, c)).
}

function quadraticPlus {
	parameter a, b, c.
	//local tmp is round(b ^ 2 - 4 * a * c, 10).
	//if tmp < 0 {
		//ptp("quadratic error: " + (b ^ 2) + " < " + (4 * a * c)).
		//ptp("a: " + a).
		//ptp("b: " + b).
		//ptp("c: " + c).
	//}
	//return (-b + sqrt(max(tmp, 0))) / (2 * a).
	return (-b + sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
	//return (-b + sqrt(b ^ 2 - 4 * a * c)) / (2 * a).
}

function quadraticMinus {
	parameter a, b, c.
	//local tmp is round(b ^ 2 - 4 * a * c, 10).
	//if tmp < 0 {
		//ptp("quadratic error: " + (b ^ 2) + " < " + (4 * a * c)).
		//ptp("a: " + a).
		//ptp("b: " + b).
		//ptp("c: " + c).
	//}
	//return (-b - sqrt(max(tmp, 0))) / (2 * a).
	return (-b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
	//return (-b - sqrt(b ^ 2 - 4 * a * c)) / (2 * a).
}

function quadraticMin {
	parameter a, b, c.
	local quad is quadratic(a, b, c).
	return min(quad[0], quad[1]).
}

function quadraticMax {
	parameter a, b, c.
	local quad is quadratic(a, b, c).
	return max(quad[0], quad[1]).
}

function clamp {
	parameter input, minimum, maximum.
	return max(min(input, maximum), minimum).
}

function invclamp {
	parameter input, minimum, maximum.
	if (input < (minimum + maximum ) / 1) { return min(input, minimum). }
	else { return max(input, maximum). }
}

function clamp360 {
	parameter deg360.
	if (abs(deg360) > 360) { set deg360 to mod(deg360, 360). }
	until deg360 > 0 {
		set deg360 to deg360 + 360.
	}
	return deg360.
}

function clamp180 {
	parameter deg180.
	set deg180 to clamp360(deg180).
	//if deg > 180 { return 360 - deg. } // always returned positive, wanted to get negative, but not sure that I'm not exploiting the bug
	if deg180 > 180 { return deg180 - 360. }
	return deg180.
}

function clamp180Positive {
	parameter deg.
	set deg to clamp360(deg).
	if deg > 180 { return 360 - deg. } // provide a function that is the same as the old bugged version of clamp180
	return deg.
}

// return the component of vector fullv along vector includev.
function vinc {
	parameter includev, fullv.
	return vxcl(vxcl(includev, fullv), fullv).
}

function ptp {
	parameter str.
	local line to "T+" + round(missiontime):tostring:padright(5):replace(" ", "-") + "- " + str.
	print line.
	//hudtext(line, 5, 4, 40, red, false).
	//log line to missionlog.
}

function alert {
	parameter str.
	// hudtext(str, 30, 3, 40, white, false).
	hudtext(str, 30, 3, 18, white, false).
	ptp(str).
}

function warn {
	parameter str.
	// hudtext(str, 60, 2, 40, yellow, false).
	hudtext(str, 60, 2, 18, yellow, false).
	ptp(str).
}

function error {
	parameter str.
	// hudtext(str, 300, 2, 40, red, false).
	hudtext(str, 300, 2, 18, red, false).
	ptp(str).
}

function verbose {
	parameter str.
	// hudtext(str, 15, 2, 40, green, false).
	hudtext(str, 15, 2, 18, green, false).
}

function verbosetime {
	parameter str, dt.
	// hudtext(str, dt, 2, 40, green, false).
	hudtext(str, dt, 2, 18, green, false).
}

function verboselong {
	parameter str.
	// hudtext(str, 45, 2, 40, green, false).
	hudtext(str, 45, 2, 18, green, false).
}

function debugprint {
	parameter str.
	print "  " + str.
}

function RadToDeg {
	parameter radians.
	return radians * 180 / PI.
}
function DegToRad {
	parameter degrees.
	return degrees * PI / 180.
}

function Lerp {
	parameter ratio, minimum, maximum.
	return ratio * (minimum - maximum) + minimum.
}

function SinH {
	parameter x.
	set x to DegToRad(x).
	return (BaseE ^ x - BaseE ^ (-x)) / 2.
}

function CosH {
	parameter x.
	set x to DegToRad(x).
	return (BaseE ^ x + BaseE ^ (-x)) / 2.
}

function TanH {
	parameter x.
	set x to DegToRad(x).
	return (BaseE ^ x - BaseE ^ (-x)) / (BaseE ^ x + BaseE ^ (-x)).
}

function ArSinH {
	parameter x.
	return RadToDeg(ln(x + sqrt(x ^ 2 + 1))).
}

function ArCosH {
	parameter x.
	return RadToDeg(ln(x + sqrt((x ^ 2) - 1))).
}

function ArTanH {
	parameter x.
	return RadToDeg(ln((1 + x) / (1 - x)) / 2).
}

function GetPolarDistance {
	parameter r1, theta1, r2, theta2.
	return sqrt(r1 ^ 2 + r2 ^ 2 - 2 * r1 * r2 * cos(theta2 - theta1)).
}

function ActivateAntennae {
	if addons:rt:available {
		local modList is ship:modulesnamed("ModuleRTAntenna").
		for mod in modList {
			local excludeTags is list("", "empty", "none").
			if mod:hasevent("Activate") { mod:doevent("Activate"). }
			if mod:hasfield("target") and not excludeTags:contains(mod:part:tag) { mod:setfield("target", mod:part:tag). }
		}
	}
	else {
		local modList is ship:modulesnamed("ModuleDataTransmitter").
		for mod in modList {
			local part is mod:part.
			if part:hasmodule("ModuleAnimateGeneric") {
				local mod2 is part:getmodule("ModuleAnimateGeneric").
				if mod2:hasevent("extend") { mod2:doevent("extend"). }
			}
			if part:hasmodule("ModuleDeployableAntenna") {
				local mod2 is part:getmodule("ModuleDeployableAntenna").
				if mod2:hasevent("Extend Antenna") { mod2:doevent("Extend Antenna"). }
			}
		}
	}
}

function OpenCargoBays {
	local modList is ship:modulesnamed("ModuleCargoBay").
	bays on.
	// for mod in modList {
	// 	if mod:part:hasmodule("ModuleAnimateGeneric") {
	// 		local mod2 is mod:part:getmodule("ModuleAnimateGeneric").
	// 		if mod2:hasevent("Open") { mod:doevent("Open"). }
	// 	}
	// }
}

function DeploySolarPanels {
	local modList is ship:modulesnamed("ModuleDeployableSolarPanel").
	panels on.
	// for mod in modList {
	// 	if mod:hasevent("Extend Panels") { mod:doevent("Extend Panels"). }
	// }
}

function RetractSolarPanels {
	local modList is ship:modulesnamed("ModuleDeployableSolarPanel").
	panels off.
	// for mod in modList {
	// 	if mod:hasevent("Retract Panels") { mod:doevent("Retract Panels"). }
	// }
}

function DisarmParachutes {
	local modList is ship:modulesnamed("ModuleParachute").
	for mod in modList {
		if mod:hasevent("Disarm") { mod:doevent("Disarm"). }
	}
}

function DeployParachutes {
	local modList is ship:modulesnamed("ModuleParachute").
	for mod in modList {
		if mod:hasevent("Deploy Chute") { mod:doevent("Deploy Chute"). }
	}
}

function DeployFairings {
	local modList is ship:modulesnamed("ModuleProceduralFairing").
	for mod in modList {
		if mod:hasevent("Deploy") { mod:doevent("Deploy"). }
	}
}

function ReleaseClamps {
	local modlist is ship:modulesnamed("LaunchClamp").
	for mod in modList {
		if mod:hasevent("Release Clamp") { mod:doevent("Release Clamp"). }
	}
}

function StartFuelCells {
	local modlist is ship:modulesnamed("ModuleResourceConverter").
	for mod in modList {
		if mod:hasfield("fuel cell") = "Fuel Cell" and mod:hasevent("Start Converter") { mod:doevent("Start Converter"). }
	}
}

function StopFuelCells {
	local modlist is ship:modulesnamed("ModuleResourceConverter").
	for mod in modList {
		if mod:hasfield("fuel cell") and mod:hasevent("Stop Converter") { mod:doevent("Stop Converter"). }
	}
}

function GetAllModulesNamed {
	parameter part, name.
	local modules is list().
	for m in part:ship:modulesnamed(name) {
		if m:part = part { modules:add(m). }
	}
	return modules.
}

function WaitForSteering {
	parameter maxRollError is 5.
	alert("Waiting for steering to settle").
	//verbosetime("Waiting for steering to settle", 20).
	local t1 is 0.
	local t2 is 0.
	if not ship:unpacked {
		error("Waiting for vessel to unpack").
		wait until ship:unpacked.
	}
	else wait 2.
	until abs(steeringmanager:angleerror) < 2 and abs(steeringmanager:rollerror) < maxRollError {
	// until vang(steering:vector, ship:facing:vector) < 2 and abs(steeringmanager:rollerror) < 5 {
		set t1 to time:seconds.
		wait until abs(steeringmanager:angleerror) < 1.
		wait until vang(steering:vector, ship:facing:vector) < 1.
		set t2 to time:seconds.
		wait min((t2 - t1 ) / 2, 5).
	}
	//verbosetime("Steering settled", 5).
	alert("Steering settled").
}

function HasFile{
	parameter filename.
	return core:currentvolume:exists(filename).
	local fl is list().
	list files in fl.
	for f in fl {
		if (f:name = filename) return true.
	}
	return false.
}

function GetFile{
	parameter filename.
	local fl is list().
	list files in fl.
	for f in fl {
		if (f:name = filename) return f.
	}
	return false.
}

function SetupPhasePrinting {
	parameter getStatusNote is { return lm_StatusNote. }.
	global lm_GetStatusNote is getStatusNote.
	if not (defined lm_StatusNote) {
		global lm_StatusNote is "".
	}
	if not (defined lm_PhaseT) {
		global lm_PhaseT is time:seconds + 2.
		global lm_PhasePrintDelegate is DoPhasePrinting@.
		when time:seconds > lm_PhaseT + 1 then {
			lm_PhasePrintDelegate:call().
			set lm_PhaseT to time:seconds.
			preserve.
		}
	}
}

function DoPhasePrinting {
	local tw is terminal:width.
	local col is tw - 10.
	SafePrintAt(core:part:tag, col, 0).
	SafePrintAt("dv: " + round(GetTotalDV()), col, 1).
	local note is lm_GetStatusNote().
	SafePrintAt(note, col, 2).
	// SafePrintAt(lm_StatusNote, col, 2).
}

function SetStatusNote {
	parameter message.
	if not (defined lm_StatusNote) {
		global lm_StatusNote is "".
	}
	set lm_StatusNote to message:tostring.
}

function SafePrintAt {
	parameter message, col, row.
	//local limit is terminal:width - col - 1.
	print message:tostring:padright(terminal:width - col - 1) at (col, row).
	//set message to "" + message.
	//if (message:length > limit) {
		//print message:substring(0, limit) at (col, row).
	//}
	//else {
		//print message:padright(limit) at (col, row).
	//}
}

function SetupVectorDebugging {
	on ag1 {
		set steeringmanager:showfacingvectors to not steeringmanager:showfacingvectors.
		set steeringmanager:showangularvectors to not steeringmanager:showangularvectors.
		verbose("facing/angular vectors to " + steeringmanager:showfacingvectors).
		preserve.
	}
	on ag2 {
		set steeringmanager:showthrustvectors to not steeringmanager:showthrustvectors.
		set steeringmanager:showrcsvectors to not steeringmanager:showrcsvectors.
		verbose("thrust/rcs vectors to " + steeringmanager:showthrustvectors).
		preserve.
	}
	on ag3 {
		set steeringmanager:showsteeringstats to not steeringmanager:showsteeringstats.
		preserve.
	}
}
function SetWarnColor {
	parameter color.
	for p in ship:partstagged("warn") {
		if (p:hasmodule("kOSLightModule")) {
			local mod to p:getmodule("kOSLightModule").
			mod:setfield("Light R", color:r).
			mod:setfield("Light G", color:g).
			mod:setfield("Light B", color:b).
			set mod to p:getmodule("ModuleLight").
			if (mod:hasevent("Lights On")) { mod:doevent("Lights On"). }
		}
	}
}

function WarpFor {
	parameter dt.
	local t1 is time:seconds + dt.
	if dt < 30 {
		warn("Wait time " + round(dt) + " is in the past, or < 30s.").
	}
	else {
		wait 1.
		set warpmode to "rails".
		local waitPacked is false.
		if warp = 0 { set waitPacked to true. }
		warpto(t1).
		if waitPacked { wait until not ship:unpacked. }
		wait 0.5.
		wait until ship:unpacked.
	}
}

function WarpForLegacy {
	parameter dt.
	// warp	(0:1) (1:5) (2:10) (3:50) (4:100) (5:1000) (6:10000) (7:100000)
	// min alt		atmo   atmo   atmo	120k	 240k	  480k	   600k
	local t1 is time:seconds + dt.
	if dt < 5 {
		print "T+" + round(missiontime) + " Warning: wait time " + round(dt) + " is in the past.".
	}
	else {
		local oldwp is 0.
		local oldwarp is warp.
		until time:seconds >= t1 {
			local rt is t1 - time:seconds.	   // remaining time
			local wp is 0.
			if rt > 5	  { set wp to 1. }
			if rt > 10	 { set wp to 2. }
			if rt > 50	 { set wp to 3. }
			if rt > 100	{ set wp to 4. }
			if rt > 1000   { set wp to 5. }
			if rt > 10000  { set wp to 6. }
			//if rt > 100000 { set wp to 7. }
			if wp <> oldwp or warp <> wp {
				set warp to wp.
				wait 0.1.
				set oldwp to wp.
				set oldwarp to warp.
			}
			wait 0.1.
		}
		wait until ship:unpacked.
	}
}
function doPendingLaunch {
	parameter craftName, site, title.
	alert("Launching new " + title).
	if (ship = kuniverse:activevessel and ContinueUnlessAnyKey(30, "initiating auto launch sequence") and ship = kuniverse:activevessel)
	{
		local template to kuniverse:getcraft(craftName, site).
		kuniverse:launchcraft(template).
		wait 5.
	}
	return false.
}
function WaitForAnyKey {
	terminal:input:clear.
	OpenTerminal().
	alert("Press any key to continue...").
	beep().
	wait until terminal:input:haschar.
	debugprint("Continuing!").
	terminal:input:clear.
}
function ContinueUnlessAnyKey {
	parameter
		duration, // The timeout before returning true regardless of input
		message. // The description of the event that may be aborted
	alert("Waiting " + duration + "s before " + message).
	debugprint("Press any key or toggle 'abort' to abort").
	OpenTerminal().
	local endTime is missiontime + duration.
	global waitComplete is false.
	local nextWaitEta is 10.
	local doAbort is false.
	on (terminal:input:haschar or waitComplete) {
		if not waitComplete {
			set doAbort to true.
			set waitComplete to true.
		}
		return false.
	}
	on missiontime {
		if endTime - missiontime <= nextWaitEta {
			verbose(nextWaitEta + " seconds...").
			set nextWaitEta to floor(nextWaitEta / 2).
			if nextWaitEta < 1 {
				set waitComplete to true.
			}
		}
		return not waitComplete.
	}
	wait until waitComplete.
	wait 0.1.
	return not doAbort.
}
function beep {
	print char(7).
}
function CloseTerminal {
	core:doaction("Close Terminal", true).
}
function OpenTerminal {
	core:doaction("Open Terminal", true).
}
