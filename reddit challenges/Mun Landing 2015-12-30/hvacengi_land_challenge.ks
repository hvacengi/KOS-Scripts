clearscreen.
set config:ipu to 2000.
set config:stat to false.
wait until ship:unpacked.
run once hvacengi_library.

local done is false.

set terminal:height to 72.
set terminal:width to 50.
sas off.
gear off.
lock throttle to 0.

set max_throttle to 0.9999.
set targetLongitude to 145.
set safeAlt to body_info[ship:body:name]["safeAlt"] + 1000.
set trueSafeAlt to body_info[ship:body:name]["safeAlt"].

set statline to "Landing on " + ship:body:name.
alert(statline).

lock hVel to vxcl(ship:up:vector, ship:velocity:surface).
lock vVel to vdot(ship:up:vector, ship:velocity:surface).

lock topvec to ship:velocity:orbit:normalized + ship:up:vector.

lock steerdir to lookdirup(-ship:velocity:surface, topvec).
lock steering to steerdir.

set steeringmanager:pitchpid:kp to 2.
set steeringmanager:yawpid:kp to 2.
set steeringmanager:rollpid:kp to 2.

set mu to ship:body:mu.

set vh to 0.
set lowestpart to ship:rootpart.
set vh to vdot(lowestpart:position, ship:facing:vector).
for p in ship:parts {
    local tmp is vdot(p:position, ship:facing:vector).
    if tmp < vh {
        set lowestpart to p.
        set vh to tmp.
    }
}
lock vesselH to -vdot(lowestpart:position - ship:rootpart:position, ship:facing:vector).
lock height to max(altitude - ship:geoposition:terrainheight - vesselH - 1, 0.01).

lock localg to mu / (ship:position - ship:body:position):mag ^ 2.
lock maxAccel to ship:availablethrust/ship:mass.
lock vAccel to ship:availablethrust/ship:mass * max(vdot(ship:up:vector, ship:facing:vector), 0.1).
lock hAccel to ship:availablethrust/ship:mass * vxcl(ship:facing:vector, ship:up:vector):mag.
lock targetAccel to vVel ^ 2 / 2 / height.

lock tset to (targetAccel + localg) / vAccel.

set burntime to 0.
set burnEta to 9 * 10^10.
set tmp1 to 0.
set tmp2 to 0.

lock impactEta to quadraticMinus((vAccel * throttle - localg) / 2, vVel, height).

declare function PrintDisplay {
    clearscreen.
    print "===LANDING STATUS===".
    //PRINT "VELOCITY".
    //print "   surface:    " + round(ship:velocity:surface:mag).
    //print "   vertical:   " + round(vVel).
    //print "   horizontal: " + round(hVel:mag).
    print "ACCELERATION".
    //print "   target:     " + round(targetAccel, 3).
    //print "   max:        " + round(maxAccel, 3).
    //print "   vertical:   " + round(vAccel, 3).
    //print "   horizontal: " + round(hAccel, 3).
    //print "   local g:    " + round(localg, 3).
    print "OTHER".
    print "   radar:      " + round(height, 3).
    print "   tset:       " + round(tset, 5).
    print "   tmp1:       " + round(tmp1, 5).
    print "   tmp2:       " + round(tmp2, 5).
    //print "   impact eta: " + round(impactEta, 2).
    //print "   free eta:   " + round(freeImpactEta, 2).
    print "   burntime:   " + round(burntime, 5).
    print "   burneta:    " + round(burnEta, 5).
    //print "   steer error:" + round(steeringmanager:angleerror, 5).
    print "STAT LINE:".
    print "   " + statline.
    print "====================".
}

declare function SetStatLine {
    declare parameter str.
    set statline to str.
    verbose(str).
}

declare function getThrottleForHeight
{
    declare parameter vel, acc, g, h.
    local tgtacc is 0.
    local thrtl is 0.
    set tgtacc to vel ^ 2 / 2 / max(h, 0.01).
    set thrtl to (tgtacc + g) / max(acc, 0.01).
    return thrtl.
}
declare function getThrottleForHorizontalBurn {
    declare parameter vel, acc, g, h.
    local tgtacc is 0.
    local thrtl is 0.
    set tgtacc to 2 * hVel:mag / max(freeImpactEta, eta:periapsis).
    set thrtl to tgtacc / hAccel.
    return thrtl.
}
declare function getThrottle {
    declare parameter vel, acc, g, h.
    if vVel > hVel:mag / 2 {
        return getThrottleForHeight(vel, acc, g, h).
    }
    else {
        return getThrottleForHorizontalBurn(vel, acc, g, h).
    }
}
declare function getImpactEta {
    declare parameter acc, thrtl, g, vel, h.
    return quadraticMinus((acc * thrtl - g), vel, h).
}
declare function setupNode {
    local bodyRotPer is ship:body:rotationperiod.
    local transferSMA is (ship:obt:semimajoraxis + ship:body:radius + trueSafeAlt) / 2.
    local transferPeriod is getOrbPer(transferSMA, ship:body:mu).
    local transferDuration is transferPeriod / 2.
    local transferLonOffset is (360 / transferPeriod - 360 / bodyRotPer) * transferDuration.
    local transferLon is clamp180(targetLongitude - transferLonOffset).
    local transferTime is time:seconds + getEtaToLon(ship, transferLon).
    getApsisNodeAt(trueSafeAlt, transferTime).
}
declare function getEtaToLon {
    declare parameter ves, lon.
    if ves:obt:eccentricity < 0.015 {
        local currentLon is clamp180(ves:longitude).
        local deltaLon is clamp360(lon - currentLon).
        local transferEta to deltalon/(360/ves:obt:period-360/ves:body:rotationperiod).
        return transferEta.
    }
    else {
        error("getEtaToLon not implemented for eccentricity >= 0.015").
        local x is 1 / 0.
    }
}
global vecdraw_landing is vecdraw(v(0,0,0), v(0,0,0), green, "", 1, true).
declare function adjustPe {
    declare parameter targetRadarAlt.
    local retro is false.
    local pro is false.
    local complete is false.
    local tsetTmp is 0.
    lock throttle to tsetTmp.
    set step to 0.01.
    until complete {
        set tsetTmp to 0.
        local peEta is eta:periapsis.
        local pePosition is positionat(ship, time:seconds + eta:periapsis).
        local peGeoNow is ship:body:geopositionof(pePosition).
        local peLon is clamp180(peGeoNow:lng - peEta * 360 / ship:body:rotationperiod).
        global peGeoThen is latlng(peGeoNow:lat, peLon).
        local radarAltThen is ship:body:altitudeof(pePosition) - peGeoThen:terrainheight.
        set vecdraw_landing:vec to peGeoThen:position - ship:body:position.
        set vecdraw_landing:start to peGeoThen:position.
        if radarAltThen > targetRadarAlt * 1.20 {
            if not retro {
                SetStatLine("Lowering Pe: " + round(radarAltThen, 2)).
                set tsetTmp to 0.
                set pro to false.
                lock steerdir to ship:retrograde.
                WaitForSteering().
                set retro to true.
                set step to step / 2.
            }
            set tsetTmp to step.
        }
        else if radarAltThen < targetRadarAlt * 0.80 {
            if not pro {
                SetStatLine("Raising Pe: " + round(radarAltThen, 2)).
                set tsetTmp to 0.
                set retro to false.
                lock steerdir to ship:prograde.
                WaitForSteering().
                set pro to true.
                set step to step / 2.
            }
            set tsetTmp to step.
        }
        else {
            alert("Landing at: (" + round(peGeoThen:lat, 1) + ", " + round(peGeoThen:lng, 1) + ") @ " + round(radarAltThen, 2)).
            set complete to true.
        }
        wait 0.
    }
    lock throttle to 0.
}
declare function getPeRadarAlt {
    local peGeo is latlng(ship:body:geopositonof(positionat(ship, time:seconds + eta:periapsis)):lat, targetLongitude).
}

// THROTTLE LOCKS
lock tsetv to getThrottleForHeight(min(vVel, 0.01), vAccel, localg, height).
lock tsetorb to 0.
lock tset to max(tsetv, tsetorb).
lock impactEta to getImpactEta(vAccel, tset, localg, vVel, height).
lock freeImpactEta to getImpactEta(0, 0, localg, vVel, height).
lock impactSpeed to velocityat(ship, time:seconds + freeImpactEta):surface:mag.

set enableDisplay to true.
set lastPrint to time:seconds.
when time:seconds > lastPrint or done then {
    if not done {
        preserve.
        if enableDisplay PrintDisplay().
        set lastPrint to time:seconds.
    }
}
WaitForSteering().

if stage:number > 0 {
    until (stage:number = 0) {
        wait until stage:ready.
        stage.
    }
    wait 2.
}

RefreshEngines().
set engineParams to GetEngineParametersAtTrtl(1).
set engineISP to engineParams[0].
set engineThrust to engineParams[1].
set engineFuelFlow to engineThrust / 9.81 / engineISP.
set engineExhaustVel to engineThrust / engineFuelFlow.

declare function GetBurnTimeDeltaVThrtl {
    declare parameter dv, thrtl.
    return ship:mass * (1 - BaseE ^ (-dv / engineExhaustVel / thrtl)) / engineFuelFlow / thrtl.
}
declare function GetDeltaMDeltaV {
    declare parameter dv.
    return ship:mass * (1 - BaseE ^ (-dv / engineExhaustVel)).
}
declare function GetThrottleDeltaVBurnTime {
    declare parameter dv, dt.
    local dm is GetDeltaMDeltaV(dv).
    local F is dm * 9.81 * engineISP / dt.
    return F / ship:availablethrust.
}
set burnend to -1.
declare function GetThrottleTemporary {
    set tmp1 to tsetv.
    if (burnend > 0) {
        set tmp2 to GetThrottleDeltaVBurnTime(velocityat(ship, time:seconds + eta:periapsis):surface:mag, burnend - time:seconds).
    }
    else {
        set tmp2 to GetThrottleDeltaVBurnTime(velocityat(ship, time:seconds + eta:periapsis):surface:mag, eta:periapsis).
    }
    if abs(vVel) > hVel:mag / 2 or tmp2 < 0 {
        lock tset to tsetv.
        lock steerdir to lookdirup(-ship:velocity:surface, topvec).
        return min(tmp1, 1).
    }
    return min(tmp2, 1).
}

set enableDisplay to false.
setupNode().
run exenode.
wait 5.

set done to false.
lock steerdir to lookdirup(-ship:velocity:surface, topvec).
lock steering to steerdir.
adjustPe(100).
set enableDisplay to true.

if (ship:altitude > (safeAlt + 500)) {
    SetStatLine("Warp to safe altitude.").
    set tgtTA to -getTA(ship:body:radius + safeAlt, ship:obt:semimajoraxis, ship:obt:eccentricity).
    set etaTA to getEtaTrueAnomOrbitable(tgtTA, ship).
    warpfor(etaTA).
    wait until ship:unpacked.
}

set impactVectorDraw to vecdraw(v(0,0,0), positionat(ship, time:seconds + freeImpactEta), red, "", 1, true).

lock steerdir to lookdirup(-ship:velocity:surface, topvec).

verbose("horizontal speed: " + round(hVel:mag)).
verbose("vertical speed: " + round(ship:verticalspeed)).
verbose("height: " + round(height)).
alert("impact eta: " + round(impactEta)).

if (vVel > 0) {
    SetStatLine("waiting for negative vertical speed").
    wait until vVel < -5.
}

SetStatLine("lock to surface retrograde.").
wait 5.
WaitForSteering().

when tset > 0.5 or impactEta < 10 then {
    set warp to 0.
    lights on.
    gear on.
}

set burnstart to 0.
set engage to false.
set factor to sqrt(2).
set burnEta to eta:periapsis.
until engage {
    set tmp2 to GetThrottleDeltaVBurnTime(velocityat(ship, time:seconds + eta:periapsis):surface:mag, eta:periapsis).
    if (tmp2 > max_throttle * 0.85)
    {
        set engage to true.
    }
    else {
        wait 0.
    }
}
lock steerdir to lookdirup(-ship:velocity:orbit, topvec).
lock tset to GetThrottleTemporary().
set burnstart to time:seconds.
set burnend to time:seconds + eta:periapsis.
lock throttle to tset.
wait 0.
alert("impact eta: " + round(impactEta)).
alert("tset: " + round(tset, 3)).

set engage to true.
until done {
    if (height < 0.1 or ship:status = "LANDED") {
        set done to true.
    }
    else if (ship:velocity:surface:mag < 10 and vVel > 0.1) {
        set done to true.
    }
    else {
        set impactVectorDraw:vec to positionat(ship, time:seconds + freeImpactEta).
        if (engage) {
            if (tset < 0.8 * max_throttle and height > 50) or (ship:velocity:surface:mag < 6) {
                lock throttle to 0.
                set engage to false.
            }
        }
        else {
            if (tset > max_throttle or height < 50) and (ship:velocity:surface:mag > 8) {
                lock throttle to tset.
                set engage to true.
            }
        }
        wait 0.
    }
}
SetStatLine("final duration: " + (time:seconds - burnstart)).
unlock throttle.
unlock steering.
wait 0.
set done to true.
wait 0.
alert("Landed!").
sas on.

wait 10.

if ship:status = "LANDED" {

    set M0 to 24.92998.
    set M1 to mass.
    set ISP to 350.
    set g0 to 9.80665.

    set DeltaV_used to g0*ISP*ln(M0/M1).

    set Rf to ship:body:radius + altitude.
    set Rcir to ship:body:radius + 100000.
    set u to ship:body:MU.
    set a to (Rf + Rcir)/2.
    set e to (Rcir - Rf)/(Rf + Rcir).
    set Vgrnd to 2*Rf*(constant():pi)/138984.38.
    set Vcir to sqrt(u/Rcir).
    set Vap to sqrt(((1 - e)*u)/((1 + e)*a)).
    set Vper to sqrt(((1 + e)*u)/((1 - e)*a)).
    set DeltaV_opt to (Vcir - Vap) + (Vper-Vgrnd).
    set Deviation to DeltaV_used - DeltaV_opt.

    print "You used " + round(Deviation,2) + "m/s more than the optimal" at(0,20).

}
