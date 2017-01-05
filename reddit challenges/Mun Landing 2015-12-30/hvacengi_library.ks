// libmath
global PI is Constant():PI.
global BaseE is Constant():E.

declare function quadraticMinus {
	declare parameter a, b, c.
	return (-b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

declare function clamp360 {
	declare parameter deg360.
	if (abs(deg360) > 360) { set deg360 to mod(deg360, 360). }
	until deg360 > 0 {
		set deg360 to deg360 + 360.
	}
	return deg360.
}

declare function clamp180 {
	declare parameter deg180.
	set deg180 to clamp360(deg180).
	//if deg > 180 { return 360 - deg. } // always returned positive, wanted to get negative, but not sure that I'm not exploiting the bug
	if deg180 > 180 { return deg180 - 360. }
	return deg180.
}

declare function RadToDeg {
	declare parameter radians.
	return radians * 180 / PI.
}
declare function DegToRad {
	declare parameter degrees.
	return degrees * PI / 180.
}

declare function ptp {
	declare parameter str.
	local line to "T+" + round(missiontime) + "---" + str.
	print line.
	hudtext(line, 5, 4, 40, red, false).
	log line to missionlog.
}

declare function alert {
	declare parameter str.
	hudtext(str, 30, 2, 40, white, false).
	ptp(str).
}

declare function warn {
	declare parameter str.
	hudtext(str, 60, 2, 40, yellow, false).
	ptp(str).
}

declare function error {
	declare parameter str.
	hudtext(str, 300, 2, 40, red, false).
	ptp(str).
}

declare function verbose {
	declare parameter str.
	hudtext(str, 15, 2, 40, green, false).
}

declare function verbosetime {
	declare parameter str, dt.
	hudtext(str, dt, 2, 40, green, false).
}

declare function verboselong {
	declare parameter str.
	hudtext(str, 45, 2, 40, green, false).
}

declare function WaitForSteering {
	verbosetime("Waiting for steering to settle", 20).
	local t1 is 0.
	local t2 is 0.
	wait 2.
    until abs(steeringmanager:angleerror) < 2 and abs(steeringmanager:rollerror) < 5 {
		set t1 to time:seconds.
        wait until abs(steeringmanager:angleerror) < 1.
		set t2 to time:seconds.
		wait min((t2 - t1 ) / 2, 5).
	}
	verbosetime("Steering settled", 20).
}

// liborbit
declare function getOrbVel {
	declare parameter r, a, mu.
	return sqrt(mu * (2 / r - 1 / a)).
}

declare function getOrbPer {
	declare parameter a, mu.
	return 2 * pi * sqrt(a^3/mu).
}

declare function getHoriVelVecAt {
	declare parameter ut.
	local rB is ship:body:position - positionat(ship, ut).
	return vxcl(rB,velocityat(ship, ut):orbit).
}

declare function getTA {
	declare parameter r, a, e.
	local p is getOrbParameter(a, e).
	print p.
	print r.
	print e.
	return arccos(p / r / e - 1 / e).
}

declare function getOrbParameter {
	declare parameter a, e.
	return a * (1 - e ^ 2).
}

declare function getEAnom {
	declare parameter eccentricity, trueanomaly.
	local E is arccos((eccentricity + cos(trueanomaly)) / (1 + eccentricity * cos(trueanomaly))).
	if (clamp360(trueanomaly) > 180) set E to 360 - E.
	return E.
}

declare function getMAnom {
	declare parameter eccentricity, EAnom.
	local ma is EAnom - RadToDeg(eccentricity * sin(EAnom)).
	return ma.
}

declare function getEtaTrueAnomOrbitable {
	declare parameter ta, ves.
	local ecc is ves:obt:eccentricity.
	local mu is ves:body:mu.
	local a is ves:obt:semimajoraxis.
	local ta0 is ves:obt:trueanomaly.
    set ta to clamp360(ta).
	local En is getEAnom(ecc, ta).
	local E0 is getEAnom(ecc, ta0).
	local Mn is getMAnom(ecc, En).
	local M0 is getMAnom(ecc, E0).
	local dM is Mn - M0.
	local eta is dM/RadToDeg(sqrt(mu/(abs(a^3)))).
	until eta > 0 {
		set eta to eta + ves:obt:period.
	}
	until eta < ves:obt:period {
		set eta to eta - ves:obt:period.
	}
	return eta.
}

declare function getNode {
	declare parameter v1, v2, rB, ut.
	local v_delta is v2 - v1.
	local v1P is v1:normalized. // normalized prograde vector
	local v1N is vcrs(v1P, rB):normalized.// normalized normal vector
	local v1R is vcrs(v1P, v1N). // normalized radial vector
	local prograde is vdot(v1P, v_delta).
	local radial is -vdot(v1R, v_delta).
	local normal is vdot(v1N, v_delta).
	return node(ut, radial, normal, prograde).
}

declare function getApsisNodeAt {
	declare parameter apsis, ut.
	local rB is positionat(ship, ut) - ship:body:position.
	local vel is getHoriVelVecAt(ut).
	local a is (apsis + ship:body:radius + rB:mag) / 2.
	set vel:mag to getOrbVel(rB:mag, a, ship:body:mu).
	local nd is getNode(velocityat(ship, ut):orbit, vel, rB, ut).
	add nd.
	return nd.
}

declare function WarpFor {
	declare parameter dt.
	local t1 is time:seconds + dt.
	if dt < 30 {
	    warn("Wait time " + round(dt) + " is in the past.").
	}
	else {
		wait 1.
		set warpmode to "rails".
		warpto(t1).
		wait until ship:unpacked.
		wait 0.5.
	}
}

// libdeltav
global ldv_engineList is list().

declare function RefreshEngines {
	list engines in ldv_engineList.
}

declare function GetISP {
	return GetISPAtTrtl(1).
}

declare function GetISPAtTrtl {
	declare parameter trtl.
	local l is GetEngineParametersAtTrtl(trtl).
	return l[0].
}

declare function GetDVAvail {
	local isp is GetISP().
	local liq is stage:liquidfuel.
	local ox is stage:oxidizer.
	local fuelmass is ox * 0.005 + liq * 0.005.
	return ln(ship:mass/(ship:mass - fuelmass))*9.81*isp.
}

declare function GetDVAvailAtTrtl {
	declare parameter trtl.
	local isp is GetISPAtTrtl().
	local liq is stage:liquidfuel.
	local ox is stage:oxidizer.
	local fuelmass is ox * 0.005 + liq * 0.005.
	return ln(ship:mass/max(ship:mass - fuelmass, 0.0001))*9.81*isp.
}

declare function GetEngineParametersAtTrtl {
	declare parameter trtl.
	local activeThrust is 0.
	local ispCounter is 0.
	for e in ldv_engineList {
		if e:ignition and e:isp > 0 {
			if e:throttlelock {
				set activeThrust to activeThrust + e:availablethrust.
				set ispCounter to ispCounter + e:availablethrust / e:isp.
			}
			else {
				set activeThrust to activeThrust + e:availablethrust * trtl.
				set ispCounter to ispCounter + e:availablethrust * trtl / e:isp.
			}
		}
	}
	if ispCounter > 0 { return list(activeThrust / ispCounter, activeThrust). }
	else { return list(0, 0). }
}

// libbody
global body_info is lex().
body_info:add("Kerbin", lex()).
body_info["Kerbin"]:add("safeAlt", 70000).
body_info:add("Mun", lex()).
body_info["Mun"]:add("safeAlt", 7048).
body_info:add("Minmus", lex()).
body_info["Minmus"]:add("safeAlt", 5725).

declare function libbody_def {
    return true.
}
