run once libmath.

function selectDockingPorts {
	local docker is findDocker().
	docker:controlfrom().
	local dockee is findDockee(docker).
	return list(docker, dockee).
}
function findDocker {
	local docker is ship:dockingports[0].
	for port in ship:dockingports {
		if (port:state = "Ready" and port:tag <> "") {
			set docker to port.
			break.
		}
	}
	verbose("Found docking source (docker " + docker:tag + ")!").
	return docker.
}
function findDockee {
	parameter docker.
	return findDockeeOnVes(docker, tgtves).
}
function findDockeeOnVes {
	parameter docker, ves.
	local dockeeFound to false.
	if ves:partstagged(docker:tag):length > 0 {
		for port in ves:dockingports {
			if (port:state = "Ready" and port:nodetype = docker:nodetype and port:tag = docker:tag) {
				local dockee is port.
				set target to dockee.
				set dockeeFound to true.
				verbose("Found docking target (dockee " + port:tag + ")!").
				return dockee.
			}
		}
	}
	if not dockeeFound {
		for port in ves:dockingports {
			if (port:state = "Ready" and port:nodetype = docker:nodetype) {
				local dockee is port.
				set target to dockee.
				set dockeeFound to true.
				verbose("Found docking target (dockee)!").
				return dockee.
			}
		}
	}
}
function requestDockee {
	parameter tgt, objective.
	ship:messages:clear().
	tgt:connection:sendmessage(list("dock", -1, objective)).
	until ship:messages:length > 0 {
		wait 1.
	}
	local msg is ship:messages:pop().
	if msg:content:istype("List")
	{
		local msgID is msg:content[0].
		if msgID = "dock" {
			local port is msg:content[1].
			local note is msg:content[2].
			if (note = "dockee") return port.
		}
	}
	local x is 1/0. // Error requesting dockee
}
function ShutdownEngines {
	verbose("Shutting down engines").
	list engines in elist.
	for e in elist {
		e:shutdown().
		if e:hasgimbal { set e:gimbal:lock to true. }
	}
}

// Dock message handling
// the vessel that is initiating the docking procedure, the one that uses RCS to fly at the other vessel is called the SHIP
// the vessel that is being docked to, that is the one that does not change its trajectory using RCS is called the STATION
// message protocol in the form of a list:
// content[0] = message identifyer, "dockShip" for messages FROM the ship and "dockStation" for messages FROM the station
// content[1] = message objective, string message to decide what you want to do like "dockeeRequest" or "dockeeResponse".
// content[2] = message payload, this contains the actual response data and should be a list if more than one piece of data is needed.
global messageHandlers is lex().
function handleMessage { // this is the handle function
	parameter listenID. // this is the messageID that the handler will look for.
	if (ship:messages:length > 0) {
		verbose("dock message received").
		local msg is ship:messages:pop().
		global lastDockMessage is msg.
		if msg:hassender { // ignore the message if it is old enough that the sender object no longer exists
			local content is msg:content.
			if content:istype("List") and content:length > 2 { // ignore the message if it is not a List and doesn't have at least 2 values
				local messageID is content[0].
				local messageObjective is content[1].
				local messageSender is msg:sender.
				local messagePayload is list().
				if content:length > 2 set messagePayload to content[2].
				if messageID = listenID {
					print content.
					print messagePayload.
					if (messageHandlers:haskey(messageObjective)) {
						messageHandlers[messageObjective]:call(messageSender, messagePayload).
					}
				}
			}
		}
	}
}
function registerMessageHandler {
	parameter objective, delegate.
	set messageHandlers[objective] to delegate.
}
function sendStationMessage { // this function is called ON THE STATION
	parameter tgt, objective, payload.
	tgt:connection:sendmessage(list("dockStation", objective, payload)).
}
function sendShipMessage { // this function is called ON THE SHIP
	parameter tgt, objective, payload.
	local success is tgt:connection:sendmessage(list("dockShip", objective, payload)).
	if not success { error("Send message failed!"). }
}
function handleDockDefault {
	parameter sender, payload.
	global dockeeVD is vecdraw(v(0,0,0), payload:position, red, "dockee", 1, true).
}
registerMessageHandler("dock", handleDockDefault@).

function dock {
	if hastarget {
		if target:istype("Vessel") {
			set tgtves to target.
		}
		else if target:istype("Part") {
			set tgtves to target:ship.
			set target to tgtves.
		}
		else {
			error("Current target is not a recognized type").
			set x to 1/0.
		}
	}
	else {
		list targets in tgts.
		set mindist to 500.
		set tgtves to ship.
		for tgt in targets {
			if (tgt:position:mag < mindist) {
				set mindist to tgt:position:mag.
				set tgtves to tgt.
			}
		}
		if tgtves = ship {
			error("No target to dock with").
			set x to 1/0.
		}
		else {
			set target to tgtves.
		}
	}
	set ports to selectDockingPorts().
	local docker to ports[0].
	local dockee to ports[1].
	sendShipMessage(tgtves, "dock", dockee:uid).
	sas off.
	dockWith(tgtves, docker, dockee).
}

function dockWith {
	parameter tgt, dockerParam, dockeeParam.
	set dockDone to false.
	global docker is dockerParam.
	global dockee is dockeeParam.
	global tgtves is tgt.
	// kuniverse:setcameratarget(dockee).
	if (stage:number > 0) {
		until stage:number = 0 {
			wait until stage:ready.
			stage.
		}
		wait 5.
	}
	ShutdownEngines().
	wait 1.

	alert("Begin docking operation...").
	set statline to "".
	set safevel to 3.

	set dockerhl to highlight(docker, green).
	set dockeehl to highlight(dockee, red).
	set docker:tag to "docker".

	//Align the two docking ports
	alert("Aligning ship with docking port").
	lock portface to dockee:portfacing.
	lock steerdir to portface * r(0,180,0).
	lock steering to steerdir.
	WaitForSteering().

	verbose("Aligned... begin translation").
	rcs on.
	//sas on.
	wait 1.
	WaitForSteering().

	// lock direction vectors and component velocities
	lock dockv to dockee:nodeposition - docker:nodeposition.
	lock tgtv to tgtves:position - ship:position.
	set dockLocal to ship:facing:inverse * dockv.
	lock xdock to dockLocal:x.
	lock ydock to dockLocal:y.
	lock zdock to dockLocal:z.

	// lock local component velocities
	lock relvelocity to ship:velocity:orbit - tgtves:velocity:orbit.
	set relVelocityLocal to ship:facing:inverse * relvelocity.
	lock xvel to relVelocityLocal:x.
	lock yvel to relVelocityLocal:y.
	lock zvel to relVelocityLocal:z.

	// Cache the relative velocity and dock distance.  Should run every update.
	when true then {
		set RawToLocal to ship:facing:inverse.
		set relVelocityLocal to RawToLocal * relvelocity.
		set dockLocal to RawToLocal * dockv.
		return not dockDone.
	}

	// initialize all pids
	set xpid to pidloop(-0.1, 0, 0, -1, 1).
	set ypid to pidloop(-0.1, 0, 0, -1, 1).
	set zpid to pidloop(-0.1, 0, -0.01, -1, 1).
	set xrcspid to pidloop(0.5, 0.1, 0, -1, 1).
	set yrcspid to pidloop(0.5, 0.1, 0, -1, 1).
	set zrcspid to pidloop(0.5, 0.1, 0, -1, 1).

	// rcs control variables
	set xrcs to 0.
	set yrcs to 0.
	set zrcs to 0.

	// directional velocity setpoints
	set xvelsp to 0.
	set yvelsp to 0.
	set zvelsp to 0.

	declare function printinfo {
		print "position--------------------".
		print "  x: " + xdock.
		print "  y: " + ydock.
		print "  z: " + zdock.
		print "error-----------------------".
		print "  x: " + xpid:error.
		print "  y: " + ypid:error.
		print "  z: " + zpid:error.
		print "pterm-----------------------".
		print "  x: " + xpid:pterm.
		print "  y: " + ypid:pterm.
		print "  z: " + zpid:pterm.
		print "iterm-----------------------".
		print "  x: " + xpid:iterm.
		print "  y: " + ypid:iterm.
		print "  z: " + zpid:iterm.
		print "velocity--------------------".
		print "  x: " + xvel.
		print "  y: " + yvel.
		print "  z: " + zvel.
		print "velocity setpoint-----------".
		print "  x: " + xvelsp.
		print "  y: " + yvelsp.
		print "  z: " + zvelsp.
		// print "controls--------------------".
		// print "  star: " + xrcs.
		// print "  top:  " + yrcs.
		// print "  fore: " + zrcs.
		print "status line-----------------".
		print statline.
	}

	on ag1 {
		verbose("Decrease gains").
		set xrcspid:kp to xrcspid:kp / 2.
		set xrcspid:ki to xrcspid:ki / 2.
		set xrcspid:kd to xrcspid:kd / 2.
		set yrcspid:kp to yrcspid:kp / 2.
		set yrcspid:ki to yrcspid:ki / 2.
		set yrcspid:kd to yrcspid:kd / 2.
		set zrcspid:kp to zrcspid:kp / 2.
		set zrcspid:ki to zrcspid:ki / 2.
		set zrcspid:kd to zrcspid:kd / 2.
		preserve.
	}
	on ag2 {
		verbose("Increase gains").
		set xrcspid:kp to xrcspid:kp * 2.
		set xrcspid:ki to xrcspid:ki * 2.
		set xrcspid:kd to xrcspid:kd * 2.
		set yrcspid:kp to yrcspid:kp * 2.
		set yrcspid:ki to yrcspid:ki * 2.
		set yrcspid:kd to yrcspid:kd * 2.
		set zrcspid:kp to zrcspid:kp * 2.
		set zrcspid:ki to zrcspid:ki * 2.
		set zrcspid:kd to zrcspid:kd * 2.
		preserve.
	}
	on ag3 {
		resetDockSetpoints().
		return true.
	}
	on abort { set dockDone to true. }

	// distance setpoints
	function resetDockSetpoints {
		if (zdock >= 20) {
			set xspt to xdock.
			set yspt to ydock.
		}
		else {
			set xspt to invclamp(xdock, -20, 20).
			set yspt to invclamp(ydock, -20, 20).
		}
		set zspt to 20.
		set xpid:setpoint to xspt.
		set ypid:setpoint to yspt.
		set zpid:setpoint to zspt.
		set xpid:ki to -0.0001.
		set ypid:ki to -0.0001.
		set zpid:ki to -0.0001.
		set waittime to time:seconds + 10.
		libdock_slerpCameraPosition(tgtves:direction * v(0, 1, -1) * 10).
		when time:seconds > waittime then {
			when abs(zspt - zdock) < 1 then {
				set xspt to 0.
				set xpid:setpoint to xspt.
				set zspt to 10.
				set zpid:setpoint to zspt.
				set statline to "Setting X setpoint to 0.".
				alert(statline).
				set steeringmanager:writecsvfiles to false.
				panels off.
				libdock_slerpCameraPosition(tgtves:direction * v(0.3, -1, -1) * 10).
				when abs(xspt - xdock) < 1 and abs(xvel) < 0.25 then {
					set yspt to 0.
					set ypid:setpoint to yspt.
					set statline to "Setting Y setpoint to 0.".
					alert(statline).
					libdock_slerpCameraPosition((dockee:nodeposition + docker:nodeposition) / 2 + dockee:portfacing:topvector * 10).
					when abs(yspt - ydock) < 0.5 and abs(yvel) < 0.25 then {
						set zspt to docker:acquirerange + 0.5.
						set zpid:setpoint to zspt.
						// set zpid:kp to zpid:kp * 1.5.
						// set zpid:ki to zpid:ki * 3.
						set statline to "Setting Z setpoint to " + zspt.
						set xrcspid:kp to xrcspid:kp * 3.
						set xrcspid:ki to xrcspid:ki * 2.
						//set xrcspid:kd to xrcspid:kd * 3.
						set yrcspid:kp to yrcspid:kp * 3.
						set yrcspid:ki to yrcspid:ki * 2.
						//set yrcspid:kd to yrcspid:kd * 3.
						set xpid:ki to -0.002.
						set ypid:ki to -0.002.
						set safevel to 1.
						alert(statline).
						libdock_slerpCameraPosition((dockee:nodeposition + docker:nodeposition) / 2 + dockee:portfacing:topvector * 5).
						when abs(xpid:error) < 0.1 and abs(xvel) < 0.25 and abs(ypid:error) < 0.1 and abs(yvel) < 0.25 and abs(zpid:error) < 0.5 then {
							when abs(xspt - xdock) < 0.1 and abs(yspt - ydock) < 0.1 and zdock < docker:acquirerange * 0.75 then { set dockDone to true. }
							set zrcspid:kp to zrcspid:kp * 3.
							set zrcspid:ki to zrcspid:ki * 2.
							//set zrcspid:kd to zrcspid:kd * 2.
							set zspt to docker:acquirerange/2.
							set zpid:setpoint to zspt.
							set xpid:ki to -0.002.
							set ypid:ki to -0.002.
							set zpid:ki to -0.001.
							// set safevel to 0.75.
							set statline to "Setting Z setpoint to " + zspt.
							alert(statline).
							libdock_slerpCameraPosition((dockee:nodeposition + docker:nodeposition) / 2 + dockee:portfacing:topvector * 5).
						}
					}
				}
			}
		}
	}
	when docker:state <> "ready" then {
		set dockDone to true.
	}
	//set steeringmanager:showfacingvectors to true.
	//set steeringmanager:showangularvectors to true.
	resetDockSetpoints().
	set dockDone to false.
	set config:stat to true.
	until (dockDone) {
		set ut to time:seconds.
		set xvelsp to xpid:update(ut, xdock) * safevel.
		set yvelsp to ypid:update(ut, ydock) * safevel.
		set zvelsp to zpid:update(ut, zdock) * safevel.
		set xrcspid:setpoint to xvelsp.
		set yrcspid:setpoint to yvelsp.
		set zrcspid:setpoint to zvelsp.
		set xrcs to xrcspid:update(ut, xvel).
		set yrcs to yrcspid:update(ut, yvel).
		set zrcs to zrcspid:update(ut, zvel).
		set ship:control:starboard to xrcs.
		set ship:control:top to yrcs.
		set ship:control:fore to zrcs.
		clearscreen.
		printinfo().
		wait 0.001.
	}
	set ship:control:neutralize to true.
	unlock steering.
	unlock throttle.

	sas on.
	rcs off.
	error("Docker state: " + docker:state).
	wait until docker:state <> "Ready" and docker:state <> "Acquire".
	error("Docker state: " + docker:state).
	set dockerhl:enabled to false.
	set dockeehl:enabled to false.
	if ship <> tgtves { set target to tgtves. }
	ptp("Docking complete").
	// set config:stat to false.
}

function libdock_slerpCameraPosition {
	parameter pos, dt is 10.
	if defined libcamera_camera {
		slerpCameraPosition(pos, dt).
	}
}
