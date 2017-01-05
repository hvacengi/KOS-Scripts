run once hvacengi_library.
{
alert("Execute node.").
lock throttle to 0.
local done is False.
wait 1.
set mannode to nextnode.
alert("Node - eta:" + round(mannode:eta) + ", dv:" + round(mannode:deltav:mag)).
set DVAvail to GetDVAvail().
set stageThreshold to mannode:deltav:mag / 2.
if (DVAvail < stageThreshold)
{
	verbose("Stage!").
	stage.
	wait until stage:ready.
	until ship:maxthrustat(0) > 0 or stage:number = 0
	{
		verbose("Stage!").
		stage.
		wait until stage:ready.
	}
	alert("DV Available: " + GetDVAvail()).
}
set maxaccel to ship:availablethrust/mass.
set maxthrottle to 1.0.
set burnduration to mannode:deltav:mag/maxaccel.
until burnduration > 2 {
	set burnduration to burnduration * 2.
	set maxthrottle to maxthrottle / 2.
}
when mannode:eta - burnduration/2 < 30 then {
	set warp to 0.  lock steering to steerdir.
	when mannode:eta - burnduration/2 < 10 then {
		set warp to 0. lock steering to steerdir.
	}
}
verbose("Node - duration:"+ round(burnduration) + ", throttle: " + round(maxthrottle, 3)).
set steerdir to ship:facing.
lock steering to steerdir.
set dv0 to mannode:deltav.
lock steerdir to lookdirup(dv0, up:vector).
WaitForSteering().
run warpfor(mannode:eta - burnduration/2 - 45).
set tset to 0.
lock throttle to tset.
set dv0 to mannode:deltav.
set stagemaxthrust to ship:maxthrustat(0).
on abort {
	set done to true.
}
when (ship:maxthrustat(0) < stagemaxthrust or ship:maxthrustat(0) < 1 or done) then {
	if not done {
		if stage:number > 0 {
			if stage:ready {
				verbose("Stage! dv: " + round(UpdateDVTrackStage())).
				stage.
				if ship:availablethrust > 0 {
					set maxthrottle to maxthrottle * maxaccel * mass / ship:availablethrust.
					verbose("Max throttle: " + maxthrottle).
				}
				set stagemaxthrust to ship:maxthrustat(0).
			}
			preserve.
		}
		else lock failed to true.
	}
}
set threshold to max(mannode:deltav:mag/300,.1).
lock steerdir to lookdirup(mannode:deltav, up:vector).
verboselong("Waiting to reach node time...").
wait until mannode:eta - burnduration/2 < 0.5.
set dv0 to mannode:deltav.
lock tsetFactor to min(10*mannode:deltav:mag/dv0:mag, 1).
lock tset to min(maxthrottle * tsetFactor, 1).
until done {
	set phystime to time:seconds.
	if mannode:deltav:mag/dv0:mag < 0.10 {
		set tset to min(10*mannode:deltav:mag/dv0:mag, 1) * maxthrottle.
	}
	if vdot(dv0, mannode:deltav) < 0 {
		lock throttle to 0.
		set done to True.
	}
	else if mannode:deltav:mag < threshold {
		if vdot(dv0, mannode:deltav) < 0.5 {
			verbose("vdot < 0.5").
			lock throttle to 0.
			set done to True.
		}
	}
	wait 0.
}
set ship:control:pilotmainthrottle to 0.
unlock steering.
unlock throttle.
wait 1.
remove mannode.
}
