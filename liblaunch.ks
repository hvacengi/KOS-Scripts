// @LAZYGLOBAL off.
run once libmath.

//if not defined liblaunch_def {

//declare function liblaunch_def {
//	return true.
//}
function beep {
	print char(7).
}

declare function getThrottleForTWR {
	declare parameter twr.
	list engines in elist.
	local lockedThrust is 0.
	local throttleThrust is 0.
	for e in elist {
		if (e:throttlelock) set lockedThrust to lockedThrust + e:availablethrust.
		else set throttleThrust to throttleThrust + e:availablethrust.
	}
	if throttleThrust = 0 return 0.
	local weight is (ship:mass * ship:body:mu / (ship:altitude + ship:body:radius)^2).
	local targetThrust is twr * weight.
	ptp("locked thrust: " + lockedThrust).
	ptp("full throttle twr:" + ((lockedThrust + throttleThrust) / weight)).
	local trtl is min(max((targetThrust - lockedThrust) / throttleThrust, 0), 1).
	ptp("thrust: " + (lockedThrust + trtl * throttleThrust)).
	ptp("twr: " + ((lockedThrust + trtl * throttleThrust) / weight)).
	return trtl.
}

declare function getAoALimitDirection {
	declare parameter targetsteer, limit.
	local v0 is ship:velocity:surface:normalized.
	local v2 is targetsteer:vector.
	if (vang(v0, v2) < limit) return targetsteer.
	local axis is vcrs(v0, v2).
	local rot is angleaxis(limit, axis).
	local v1 is rot * v0.
	return lookdirup(v1, targetsteer:topvector).
}

declare function getSteeringAdjustVelocity {
	declare parameter v1.
	local v0 is ship:velocity:surface:normalized.
	local dv is v1 - v0.
	set vd_v0 to vecdraw(v(0,0,0), v0 * 50, red, "", 1, true).
	set vd_v1 to vecdraw(v(0,0,0), v1 * 50, blue, "", 1, true).
	return v1.
}

global liblaunch_maxQ is 0.
declare function pastMaxQ {
	if (ship:q < 0.95 * liblaunch_maxQ) {
		return true.
	}
	set liblaunch_maxQ to max(liblaunch_maxQ, ship:q).
	return false.
}

function warpToLaunchPhaseAngle {
	parameter tgt, phaseAngle1.
	local oldTag is core:part:tag.
	local phaseAngle0 is clamp360(getPhaseAngle(ship, tgt)) - 360.
	local phaseAngleDelta is clamp360(phaseAngle1 - phaseAngle0).
	local phaseAngle is phaseAngle0.
	local dt is -phaseAngleDelta / ((360 / ship:body:rotationperiod) - (360 / tgt:orbit:period)).
	alert("Current phase angle:    " + round(phaseAngle0)).
	alert("Warping to phase angle: " + phaseAngle1).
	alert("Phase angle delta:      " + round(phaseAngleDelta)).
	// alert("DT: " + dt).
	local endTime is time:seconds + dt.
	if (dt > 60 * 60) {
		warpto(endTime - 60 * 5).
		wait until not ship:unpacked.
		until ship:unpacked {
			set phaseAngle to getPhaseAngle(ship, tgt).
			set core:part:tag to "" + round(phaseAngle, 2).
			wait 0.
		}
	}
	warpto(endTime - 5).
	wait until not ship:unpacked.
	until ship:unpacked {
		set phaseAngle to getPhaseAngle(ship, tgt).
		set core:part:tag to "" + round(phaseAngle, 2).
		wait 0.
	}
	// alert("Post-warp phase angle: " + round(getPhaseAngle(ship, tgtvessel))).
	local phaseAngleExecute is phaseAngle1 + 10 * ((360 / ship:body:rotationperiod) - (360 / tgt:orbit:period)).
	wait until ship:unpacked.
	// alert("Phase angle at execute: " + round(phaseAngleExecute, 2)).
	until getPhaseAngle(ship, tgt) >= phaseAngleExecute {
		set phaseAngle to getPhaseAngle(ship, tgt).
		set core:part:tag to "" + round(phaseAngle, 2).
		wait 0.
	}
	set core:part:tag to oldTag.
	set warp to 0.
	alert("Warping finished, waiting for warp to settle.").
	wait until kuniverse:timewarp:issettled.
	alert("Settled").
	set ship:control:pilotmainthrottle to 0.
}

function FindLowestPart {
	local lowestpart is ship:rootpart.
	local vh to vdot(lowestpart:position, ship:facing:vector).
	for p in ship:parts {
		local tmp is vdot(p:position, ship:facing:vector).
		if tmp < vh {
			set lowestpart to p.
			set vh to tmp.
		}
	}
	return lowestpart.
}
function FindHighestPart {
	local hightestpart is ship:rootpart.
	local vh to vdot(lowestpart:position, ship:facing:vector).
	for p in ship:parts {
		local tmp is vdot(p:position, ship:facing:vector).
		if tmp > vh {
			set hightestpart to p.
			set vh to tmp.
		}
	}
	return hightestpart.
}
function FindVesselHeight {
	local lowestpart is ship:rootpart.
	local highestPart is ship:rootpart.
	local vhLow to vdot(lowestpart:position, ship:facing:vector).
	local vhHigh to vdot(highestPart:position, ship:facing:vector).
	for p in ship:parts {
		local tmp is vdot(p:position, ship:facing:vector).
		if tmp < vhLow {
			set lowestpart to p.
			set vhLow to tmp.
		}
		if tmp > vhHigh {
			set highestPart to p.
			set vhHigh to tmp.
		}
	}
	return (lowestPart:position - highestPart:position):mag.
}

function defaultTurn {
	declare parameter targetalt, targetinc, targettwr, pitchangle, pitchalt.

	// attitude control
	sas off.
	lock steerdir to lookdirup(up:vector, ship:facing:topvector).
	global liblaunch_pitchalt is pitchalt.
	global liblaunch_targetAz is targetAz.
	global liblaunch_targetInc is targetinc.
	lock steering to steerdir.
	when ship:altitude > liblaunch_startalt + liblaunch_pitchalt then {
		sas off.
		//rcs on.
		set state to 2.
		set core:part:tag to tagbase + ".2".
		//lock steerdir to lookdirup(getSteeringAdjustVelocity(heading(liblaunch_targetAz, 90 + pitchangle):vector), ship:facing:topvector).
		// lock steerdir to heading(liblaunch_targetAz, 90 + liblaunch_pitchangle).
		lock steerdir to heading(getAzForInc(liblaunch_targetInc), 90 + liblaunch_pitchangle).
		// lock steering to steerdir.
		alert("Beginning turn.").
		liblaunch_slerpCameraPosition(heading(90, 0) * v(0, 1, 0) * FindVesselHeight() * 2, 30).
		lock steerangleofattack to vang(ship:velocity:surface, steerdir:vector).
		when (steerangleofattack < (abs(liblaunch_pitchangle) * 0.1)) or (steerangleofattack > (abs(liblaunch_pitchangle) * 2)) or ship:airspeed > 75 then {
			//lock steerdir to lookdirup(getSteeringAdjustVelocity(heading(liblaunch_targetAz, 90 - vang(ship:up:vector, ship:velocity:surface)):vector), ship:facing:topvector).
			// lock steerdir to heading(liblaunch_targetAz, 90 - vang(ship:up:vector, ship:velocity:surface)).
			lock steerdir to heading(getAzForInc(liblaunch_targetInc), 90 - vang(ship:up:vector, ship:velocity:surface)).
			verbose("Maintain surface pitch, " + round(steerangleofattack, 5)).
			when ship:altitude > 10000 then {
				liblaunch_slerpCameraPosition(facing * r(15, -30, 0):vector * 40).
			}
			when ship:altitude > 30000 then {
				alert("Entering upper atmosphere.").
				// lock steerdir to lookdirup(ship:prograde:vector, up:vector).
				lock steerdir to prograde.
				// lock steering to steerdir.
				liblaunch_slerpCameraPosition(prograde * v(-5, 5, 30)).
				if state < 3 { set state to 3. set core:part:tag to tagbase + ".3". }
				when ship:altitude > 35000 then {
					alert("RCS off, jettison fairings.").
					rcs off.
					UpdateDVTrackStage().
					toggle ag4.
					liblaunch_slerpCameraPosition(prograde * v(10, 10, -10)).
				}
				when ship:altitude > 40000 then {
					alert("Second jettison.").
					toggle ag5.
				}
			}
		}
	}
	// throttle control
	//when pastMaxQ() or vang(ship:up:vector, ship:facing:vector) > 50 then {
	global liblaunch_targetalt is targetalt.
	when ship:altitude > 12500 or vang(ship:up:vector, ship:facing:vector) > 37.5 then {
		verbose("Throttle up.").
		lock throttle to tset.
		when ship:apoapsis > 0.90 * liblaunch_targetalt then {
			set tsetOld to tset.
			set tset to 0.5 * tsetOld.
			when ship:apoapsis > liblaunch_targetalt then {
				alert("Ap at " + round(ship:apoapsis/1000, 5) + "km!").
				set state to 4.
				set core:part:tag to tagbase + ".4".
				set tset to 0.
				liblaunch_slerpCameraPosition(prograde * v(20, 20, 0)).
			}
		}
	}
}

function getMechJebFlightAngle {
	parameter startalt, endalt, tuningparameter, endingangle.
	local current is ship:altitude - startalt.
	local travel is endalt - startalt.
	local pitch is 90 - (current / travel) ^ (tuningparameter / 100) * (90 - endingangle).
	return pitch.
}

function velocityTurn {
	declare parameter targetalt, targetinc, targettwr, pitchangle, pitchalt.

	error("Using Velocity Turn").

	// attitude control
	sas off.
	lock steerdir to lookdirup(up:vector, ship:facing:topvector).
	global liblaunch_pitchalt is pitchalt.
	global liblaunch_targetAz is targetAz.
	global liblaunch_targetInc is targetinc.
	lock steering to steerdir.
	when ship:velocity:surface:mag > liblaunch_pitchalt then {
		sas off.
		set state to 2.
		set core:part:tag to tagbase + ".2".
		//lock steerdir to lookdirup(getSteeringAdjustVelocity(heading(liblaunch_targetAz, 90 + pitchangle):vector), ship:facing:topvector).
		// lock steerdir to heading(liblaunch_targetAz, 90 + liblaunch_pitchangle).
		lock steerdir to heading(getAzForInc(liblaunch_targetInc), 90 + liblaunch_pitchangle).
		alert("Beginning turn.").
		liblaunch_slerpCameraPosition(heading(90, 0) * v(0, 1, 0) * FindVesselHeight() * 2, 30).
		lock steerangleofattack to vang(ship:velocity:surface, steerdir:vector).
		when (steerangleofattack < (abs(liblaunch_pitchangle) * 0.1)) or (steerangleofattack > (abs(liblaunch_pitchangle) * 2)) or ship:airspeed > 75 then {
			//lock steerdir to lookdirup(getSteeringAdjustVelocity(heading(liblaunch_targetAz, 90 - vang(ship:up:vector, ship:velocity:surface)):vector), ship:facing:topvector).
			// lock steerdir to heading(liblaunch_targetAz, 90 - vang(ship:up:vector, ship:velocity:surface)).
			lock steerdir to heading(getAzForInc(liblaunch_targetInc), 90 - vang(ship:up:vector, ship:velocity:surface)).
			verbose("Maintain surface pitch, " + round(steerangleofattack, 5)).
			when ship:altitude > 30000 then {
				alert("Entering upper atmosphere.").
				liblaunch_slerpCameraPosition(prograde * v(-5, 5, 30)).
				lock steerdir to lookdirup(ship:prograde:vector, up:vector).
				// lock steering to steerdir.
				if state < 3 { set state to 3. set core:part:tag to tagbase + ".3". }
				when ship:altitude > 35000 then {
					alert("RCS off, jettison fairings.").
					rcs off.
					UpdateDVTrackStage().
					toggle ag4.
					liblaunch_slerpCameraPosition(prograde * v(10, 10, -10)).
				}
				when ship:altitude > 40000 then {
					alert("Second jettison.").
					toggle ag5.
				}
			}
		}
	}

	// throttle control
	//when pastMaxQ() or vang(ship:up:vector, ship:facing:vector) > 50 then {
	global liblaunch_targetalt is targetalt.
	when ship:altitude > 12500 or vang(ship:up:vector, ship:facing:vector) > 37.5 then {
		verbose("Throttle up.").
		lock throttle to tset.
		when ship:apoapsis > 0.90 * liblaunch_targetalt then {
			set tsetOld to tset.
			set tset to 0.5 * tsetOld.
			when ship:apoapsis > liblaunch_targetalt then {
				alert("Ap at " + round(ship:apoapsis/1000, 5) + "km!").
				set state to 4.
				set core:part:tag to tagbase + ".4".
				set tset to 0.
			}
		}
	}
}

declare function launch {
	declare parameter targetalt, targetinc, targettwr, pitchangle, pitchalt, turnfunc is defaultTurn@.
	//global pitchalt is param_pitchalt.
	global tagbase is core:part:tag.
	global liblaunch_pitchangle is pitchangle.
	if status = "prelaunch" or status = "landed" or (defined initstatus and initstatus = "prelaunch") {
		set core:part:tag to tagbase + ".0".
		global done is false.
		global state to 0.
		global liblaunch_startalt to ship:altitude.
		lock tset to 1.0.
		lock throttle to tset.
		lock targetAz to 90.
		sas on.
		gear off.
		verbose("Counting down:").
		if core:part:hasmodule("kOSLightModule") {
			if core:part:getmodule("ModuleLight"):hasevent("Lights On") {
				core:part:getmodule("ModuleLight"):doevent("Lights On").
			}
		}
		for cd in range(10, 0) {
			verbosetime(cd + "...", 0.75).
			beep().
			wait 1.
		}
		verboselong("Ignition!").
		set state to 1.
		stage.
		until ship:availablethrust > 0 {
			verbose("0 Thrust, Stage!").
			wait until stage:ready.
			stage.
		}
		global maxthrottle is getThrottleForTWR(targettwr).
		lock throttle to maxthrottle.

		// stage control
		global stagemaxthrust to ship:maxthrustat(0).
		when (ship:maxthrustat(0) < stagemaxthrust or (ship:maxthrustat(0) < 1) or done) then {
			if not done {
				if stage: number > 0 {
					if stage:ready {
						verboselong("Stage! dv: " + round(UpdateDVTrackStage())).
						stage.
						set stagemaxthrust to ship:maxthrustat(0).
						set maxthrottle to max(getThrottleForTWR(targettwr), maxthrottle).
						liblaunch_slerpCameraPosition(ship:facing * v(0, 10, 30), 1).
					}
					preserve.
				}
				else lock failed to true.
			}
		}

		// Call turnfunc to control attitude
		turnfunc:call(targetalt, targetinc, targettwr, pitchangle, pitchalt).

		if ship:modulesnamed("LaunchClamp"):length > 0 {
			wait 0.25.
			wait until stage:ready.
			stage.
		}
		alert("Lift off!").
		until state = 4 and ship:altitude > 70500.0 {
			if state = 4 and ship:apoapsis < targetalt - 250 {
				set state to 3.
				set tset to 0.1.
				when ship:apoapsis > targetalt then {
					verbose("Ap at " + round(ship:apoapsis/1000, 5) + "km!").
					set state to 4.
					set core:part:tag to tagbase + ".4".
					set tset to 0.
				}
			}
			UpdateDVTrack().
			wait 0.
		}
		wait 0.25.
		if ship:apoapsis < targetalt {
			verbose("Fine tuning Ap.").
			when ship:apoapsis > targetalt then {
				set tset to 0.
				alert("Ap at " + round(ship:apoapsis/1000, 5) + "km!").
				set state to 5.
				set core:part:tag to tagbase + ".5".
			}.
			set tset to 0.1.
			wait until state = 5.
		}
		UpdateDVTrack().
		set ship:control:pilotmainthrottle to 0.
		unlock steering.
		unlock throttle.
		clearvecdraws().
		set done to true.
		wait 0.
		verbose("Launch phase complete").
		set core:part:tag to tagbase.
	}
	else {
		error("Cannot launch, not at prelaunch status.").
		error("ship:status = " + ship:status).
		wait 10.
		core:doaction("Close Terminal", true).
		wait 0.
		kuniverse:reverttolaunch().
		shutdown.
		wait 10.
	}
}
function loadLaunchProfile {
	parameter defaultAltitude is 100000, defaultInclination is 0, defaultTWR is 1.2125, defaultShape is -1.75, defaultTurnAltitude is 200, defaultHoldingAltitude is 75000.
	set path to "0:/launch-profiles/" + ship:name + "/launch.json".
	if exists(path) {
		global l is readjson(path).
		global LaunchAltitude is l[0].
		global LaunchInclination is l[1].
		global LaunchTWR is l[2].
		global LaunchShape is l[3].
		global TurnAltitude is l[4].
		global HoldingAltitude is l[5].
	}
	else {
		global LaunchAltitude is defaultAltitude.
		global LaunchInclination is defaultInclination.
		global LaunchTWR is defaultTWR.
		global LaunchShape is defaultShape.
		global TurnAltitude is defaultTurnAltitude.
		global HoldingAltitude is defaultHoldingAltitude.
		writejson(list(LaunchAltitude, LaunchInclination, LaunchTWR, LaunchShape, TurnAltitude, HoldingAltitude), path).
	}
	global LaunchProfilePath is path.
}

function liblaunch_slerpCameraPosition {
	parameter pos, dt is 10.
	if defined libcamera_camera {
		slerpCameraPosition(pos, dt).
	}
}
