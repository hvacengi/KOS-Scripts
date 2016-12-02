@LAZYGLOBAL off.

run once libmath.
run once liborbit.
run once libdeltav.

function getHorizontal {
	parameter vec.
	return vxcl(ship:up:vector, vec).
}
function getVertical {
	parameter vec.
	return vxcl(vxcl(ship:up:vector, vec), vec).
}
function getFlightAngle {
	return 90 - vang(ship:up:vector, ship:velocity:surface).
}
function getEngineAccel {
	if true {
		//RefreshEngines().
		local g0 is 9.81.
		local engineParams is GetEngineParametersAtTrtl(1).
		local engineThrust is engineParams[1].
		local accel is engineThrust / ship:mass.
		return accel.
	}
	else {
		local accel is ship:availablethrust / ship:mass.
	}
}
function getEngineAccelVec {
	return ship:facing:vector * getEngineAccel().
}
function getLocalG {
	return ship:body:mu / (ship:position - ship:body:position):mag ^ 2.
}
function getLocalGVec {
	return ship:up:vector * -getLocalG().
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
function getThrottleForHeight
{
	parameter vel, acc, g, h.
	// vel is the current vertical velocity
	// acc is the current available vertical acceleration based on current pitch
	// g is the local acceleration due to gravity
	// h is the height, it is very important that this is calibrated to
	// account for the offset of the bottom of the vessel from the CoM
	// negative values of tgtacc mean accelerating towards the body (down),
	// positive values mean accelerating away from the body (up).
	return getThrottleForHeightVf(vel, acc, g, h, 0).
	// return getThrottleForHeightVf(vel, acc, g, h, 0.5).
	// local tgtacc is 0.
	// local thrtl is 0.
	// set tgtacc to vel ^ 2 / 2 / max(h, 0.01).
	// set thrtl to (tgtacc + g) / max(acc, 0.01).
	// return thrtl.
}
function getThrottleForHeightVf
{
	parameter vel, acc, g, h, velFinal.
	// vel is the current vertical velocity
	// acc is the current available vertical acceleration based on current pitch
	// g is the local acceleration due to gravity
	// h is the height, it is very important that this is calibrated to
    // velFinal is the desired final velocity.
	// account for the offset of the bottom of the vessel from the CoM
	// negative values of tgtacc mean accelerating towards the body (down),
	// positive values mean accelerating away from the body (up).
	local tgtacc is 0.
	local thrtl is 0.
	set tgtacc to -1 * (velFinal ^ 2 - vel ^ 2) / 2 / max(h, 0.01).
	set thrtl to (tgtacc + g) / max(acc, 0.01).
	return thrtl.
}
function getThrottleForHorizontalBurn {
	parameter vel, acc, g, h.
	local tgtacc is 0.
	local thrtl is 0.
	local hVel is getHorizontal(vel).
	set tgtacc to 2 * hVel:mag / eta:periapsis.
	set thrtl to tgtacc / acc.
	return thrtl.
}
function getImpactEta {
	parameter acc, thrtl, g, vel, h.
	// acc is max vertical thrust acceleration
	// thrtl is the throttle set point
	// g is the local acceleration due to gravity
	// vel is the vertical velocity
	// h is the height above the terrain
	// returned value assumes constant acceleration and as
	// such is slightly inaccurate (provides safety factor)
	return quadraticMinus((acc * thrtl - g), vel, h).
}
function getEtaToLon {
	parameter ves, lon.
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
function getGeoAtEta {
	parameter etaGeo.
	local posGeo is positionat(ship, time:seconds + etaGeo).
	return getGeoAtEtaPos(etaGeo, posGeo).
}
function getGeoAtEtaPos {
	parameter etaGeo, pos.
	local geoNow is ship:body:geopositionof(pos).
	local lonShift is etaGeo * 360 / ship:body:rotationperiod.
	if (ship:obt:inclination > 90) set lonShift to -lonShift.
	// TODO: Need to detect retrograde orbits and adjust the shift accordingly
	local geoThen is latlng(geoNow:lat, geoNow:lng - lonShift).
	return geoThen.
}
function getGeoAt {
	parameter ut.
	return getGeoAtEta(ut - time:seconds).
}
function getPeGeo {
	return getGeoAtEta(eta:periapsis).
}
function getPeRadarAlt {
	parameter heightOffset.
	// heightOffset is the difference between the CoM and the lowest point of the ship
	local peGeo is getPeGeo().
	local h is alt:periapsis - peGeo:terrainheight - heightOffset.
	return h.
}
function getAltitudeEta {
    parameter tgtAltitude.
	local tgtTA is -getTA(ship:body:radius + min(max(tgtAltitude, periapsis), apoapsis), ship:obt:semimajoraxis, ship:obt:eccentricity).
	local etaTA is getEtaTrueAnomOrbitable(tgtTA, ship).
    return etaTA.
}
