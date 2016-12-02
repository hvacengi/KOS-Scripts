@LAZYGLOBAL off.

declare function liborbit_def {
	return true.
}

global liborbit_debug is false.
global liborbit_drawvectors is false.

declare function getAFromPeriodMu {
	declare parameter period, mu.
	return (((period / (2 * pi)) ^ 2) * mu) ^ (1 / 3).
	return (period * sqrt(mu) / (2 * pi)) ^ (2 / 3).
}

declare function getOrbVel {
	declare parameter r, a, mu.
	return sqrt(mu * (2 / r - 1 / a)).
}

declare function getOrbPer {
	declare parameter a, mu.
	return 2 * pi * sqrt(a^3/mu).
}

declare function getOrbR {
	declare parameter a, ta, e.
	return a * (1 - e^2) / (1 + e * cos(ta)).
}

declare function getTA {
	declare parameter r, a, e.
	local p is getOrbParameter(a, e).
	// print p.
	// print r.
	// print e.
	return arccos(clamp(p / r / e - 1 / e, -1, 1)).
	//return arccos((p / r - 1) / e).
	//return arccos((p - r) / e / r).
}

declare function getOrbParameter {
	declare parameter a, e.
	return a * (1 - e ^ 2).
}

declare function getOrbFlightPathAng {
	declare parameter ta, e.
	return arctan2(e * sin(ta), (1 + e * cos(ta))).
}

declare function getMeanMotion {
	declare parameter mu, a.
	return (mu / a ^ 3) ^ 0.5.
}

declare function getGeoLAN {
	local i is ship:obt:inclination.
	local lat is ship:latitude.
	local lon is ship:longitude.
	local dgamma is arctan(sin(lat)/(tan(arcsine(cos(i)/cos(lat))))).
	return lon - dgamma.
}

declare function getPerpVelVecAt {
	declare parameter ut.
	local rB is ship:body:position - positionat(ship, ut).
	local vN is vcrs(velocityat(ship, ut):orbit, rB).
	return vcrs(rB, vN):normalized.
}

declare function getHoriVelVecAt {
	declare parameter ut.
	local rB is ship:body:position - positionat(ship, ut).
	return vxcl(rB,velocityat(ship, ut):orbit).
}

declare function getHoriVelVecOrbitableAt0 {
	declare parameter tgt, ut.
	local pos0 is tgt:body:position.
	local pos1 is positionat(tgt, ut).
	local rB is pos1 - pos0.
	//if tgt = sun { set rB to positionat(tgt, ut) - tgt:body:position. }
	if (liborbit_drawvectors) {
		global vd_rB1 is vecdraw(tgt:position, rB, yellow, "", 1, true).
		global vd_rB2 is vecdraw(tgt:position, (pos1 - pos0), purple, "", 1, true).
		global vd_rB3 is vecdraw(v(0,0,0), pos0, green, "", 1, true).
		global vd_rB4 is vecdraw(v(0,0,0), pos1, blue, "", 1, true).
		global vd_rB5 is vecdraw(pos0, rB, red, "", 1, true).
	}
	//wait until ag10.
	return vxcl(rB,velocityat(ship, ut):orbit).
}

declare function getDistance {
	declare parameter r1, ta1, lan1, aop1, r2, ta2, lan2, aop2.
	return GetPolarDistance(r1, ta1 + lan1 + aop1, r2, ta2 + lan2 + aop2).
}

// return a maneuver node to
declare function getNode {
	declare parameter v1, v2, rB, ut.
	local v_delta is v2 - v1.
	//verbose("v_delta: " + v_delta).
	// print v_delta:mag.
	local v1P is v1:normalized. // normalized prograde vector
	// print rB.
	// print v1.
	local v1N is vcrs(v1P, rB):normalized.// normalized normal vector
	local v1R is vcrs(v1P, v1N). // normalized radial vector
	local prograde is vdot(v1P, v_delta).
	local radial is -vdot(v1R, v_delta).
	local normal is vdot(v1N, v_delta).
	if (liborbit_drawvectors) {
		global vd_vP is vecdraw(body:position + rB, v1P * 1000, red, "prograde", 1, true).
		global vd_vN is vecdraw(body:position + rB, v1N * 1000, purple, "normal", 1, true).
		global vd_vR is vecdraw(body:position + rB, v1R * 1000, blue, "radial", 1, true).
	}
	local nd is node(ut, radial, normal, prograde).
	wait 0.
	return nd.
}
// return a maneuver node to
declare function getNodeDv {
	declare parameter v1, v_delta, rB, ut.
	//verbose("v_delta: " + v_delta).
	// local v_delta is v2 - v1.
	// print v_delta:mag.
	local v1P is v1:normalized. // normalized prograde vector
	// print rB.
	// print v1.
	local v1N is vcrs(v1P, rB):normalized.// normalized normal vector
	local v1R is vcrs(v1P, v1N). // normalized radial vector
	local prograde is vdot(v1P, v_delta).
	local radial is -vdot(v1R, v_delta).
	local normal is vdot(v1N, v_delta).
	local nd is node(ut, radial, normal, prograde).
	wait 0.
	return nd.
}

declare function fixLonShift {
	declare parameter lon.
	return mod(lon + 360 + 180, 360) - 180.
}

declare function fixLon {
	declare parameter lon.
	return mod(lon + 360 + 180, 360).
}
declare function etaToLAN {
	declare parameter obt.
	local E1 is getObtE.
}

declare function getTAnom {
	declare parameter eccentricity, ea.
	set ea to clamp180(ea).
	if eccentricity > 1 {
		local ta is arccos((CosH(ea) - eccentricity) / (1 - eccentricity * CosH(ea))).
		if (ea < 0) set ta to 360 - ta.
		return ta.
	}
	local ta is 2 * arctan(((1 + eccentricity) / (1 - eccentricity)) ^ 0.5 * tan(ea / 2)).
	return clamp360(ta).
}

declare function getEAnom {
	declare parameter eccentricity, trueanomaly.
	if eccentricity > 1 {
		set trueanomaly to clamp180(trueanomaly).
		local E is ArCosH((eccentricity + cos(trueanomaly)) / (1 + eccentricity * cos(trueanomaly))).
		if (trueanomaly < 180) set E to 360 - E.
		return E.
	}
	local E is arccos((eccentricity + cos(trueanomaly)) / (1 + eccentricity * cos(trueanomaly))).
	if (clamp360(trueanomaly) > 180) set E to 360 - E.
	return E.
}

declare function approxEAnom {
	declare parameter ecc, ma.
	local done is false.
	local ea_n is ma.
	local ea_n1 is 0.
	local itt is 0.
	until done = true {
		if ecc > 1 {
			set ea_n1 to ea_n + (ma + ea_n - RadToDeg(ecc * SinH(ea_n))/RadToDeg(ecc * CosH(ea_n) - 1)).
		}
		else {
			set ea_n1 to ea_n + (ma - ea_n + RadToDeg(ecc * sin(ea_n))/RadToDeg(1 - ecc * cos(ea_n))).
		}
		set ea_n1 to ea_n + (ma - ea_n + RadToDeg(ecc * sin(ea_n))/RadToDeg(1 - ecc * cos(ea_n))).
		if abs(ea_n/ea_n1) > 0.9999 { set done to true. }
		else {
			set itt to itt + 1.
			if itt > 100 {
				set done to true.
				warn("approxEAnom: max iterations reached, ratio: " + round(abs(ea_n/ea_n1), 5)).
			}
		}
		set ea_n to ea_n1.
	}
	return ea_n.
}

declare function getMAnom {
	declare parameter eccentricity, EAnom.
	if eccentricity > 1 {
		return RadToDeg(eccentricity * SinH(EAnom)) - EAnom.
	}
	local ma is EAnom - RadToDeg(eccentricity * sin(EAnom)).
	return ma.
}

declare function getEtaTrueAnom {
	declare parameter trueanomaly.
	return getEtaTrueAnomOrbitable(trueanomaly, ship).
}

declare function getEtaTrueAnomOrbitable {
	declare parameter ta, ves.
	// if (ta < ves:obt:trueanomaly) set ta to ta + 360.
	local ecc is ves:obt:eccentricity.
	local mu is ves:body:mu.
	local a is ves:obt:semimajoraxis.
	local ta0 is ves:obt:trueanomaly.
	if (ecc > 1) {
		set ta0 to clamp180(ta0).
		//local r is (ship:position - ship:body:position):mag.
		set ta to clamp180(ta).
		local F0 is ArCosH((ecc + cos(ta0)) / (1 + ecc * cos(ta0))).
		//local F0 is ArTanH(sqrt((e - 1) / (e + 1)) * tan(ta0 / 2)).
		if ta0 < 0 set F0 to -F0.
		local Fn is ArCosH((ecc + cos(ta)) / (1 + ecc * cos(ta))).
		//local Fn is ArTanH(sqrt((e - 1) / (e + 1)) * tan(ta / 2)).
		if ta < 0 set Fn to -Fn.
		local M0 is RadToDeg(ecc * SinH(F0)) - F0.
		local Mn is RadToDeg(ecc * SinH(Fn)) - Fn.
		local t0 is M0 / RadToDeg(sqrt(mu / abs(a^3))).
		local tn is Mn / RadToDeg(sqrt(mu / abs(a^3))).
		//print "ecc: " + ecc.
		//print "a:   " + a.
		//print "mu:  " + mu.
		//print "TA0: " + ta0.
		//print "TAn: " + ta.
		//print "FA0: " + F0.
		//print "FAn: " + Fn.
		//print "MA0: " + M0.
		//print "MAn: " + Mn.
		//print "t0:  " + t0.
		//print "tn:  " + tn.
		return tn - t0.
	}
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

declare function getEtaRadiusOrbitable {
	declare parameter r, ves.
}

declare function getMatchIncNode {
	declare parameter tgt.
	local r1 to ship:position - ship:body:position.
	local v1 to ship:velocity:orbit.
	local h1 to vcrs(r1, v1).
	local r2 to tgt:position - tgt:body:position.
	local v2 to tgt:velocity:orbit.
	local h2 to vcrs(r2, v2).
	local i_rel to vang(h1, h2).
	local r_an to vcrs(h1, h2).
	global vd_r_an is vecdraw(body:position, r_an, red, "Ascending node", 1, true).
	local dta_an to vang(r1, r_an).
	if vdot(vcrs(h1, r1), r_an) < 0 { set dta_an to clamp360(dta_an * -1). }
	if dta_an > 180 { set dta_an to dta_an - 180. set i_rel to -1 * i_rel. }
	local ut_an to time:seconds + getEtaTrueanom(ship:obt:trueanomaly + dta_an).
	local r3 to positionat(ship, ut_an) - ship:body:position.
	local v3 to velocityat(ship, ut_an):orbit.
	local v3_horiz to vxcl(r3, velocityat(ship, ut_an):orbit).
	local dvNorm to vcrs(v3_horiz, r3):normalized * (v3_horiz:mag * sin(i_rel * -1)).
	local dvPro to v3_horiz:normalized * (v3_horiz:mag * cos(i_rel)).
	local v4_horiz to dvNorm + dvPro.
	local v_delta to v4_horiz - v3_horiz.
	local nd to getNodeDv(v3, v_delta, r3, ut_an).
	add nd.
	wait 0.
	return nd.
}

declare function getChangeInc {
	declare parameter i1, i2, lan1, lan2.
	// based on http://www.braeunig.us/space/orbmech.htm#plnchng
	if liborbit_debug {
		ptp("i1: " + i1 + ", lan1: " + lan1).
		ptp("i2: " + i2 + ", lan2: " + lan2).
	}
	local a1 to sin(i1) * cos(lan1).
	local a2 to sin(i1) * sin(lan1).
	local a3 to cos(i1).
	local b1 to sin(i2) * cos(lan2).
	local b2 to sin(i2) * sin(lan2).
	local b3 to cos(i2).
	local xfrAng to arccos(a1 * b1 + a2 * b2 + a3 * b3). // relative inclination
	local c1 to a2 * b3 - a3 * b2.
	local c2 to a3 * b1 - a1 * b3.
	local c3 to a1 * b2 - a2 * b1.
	local xfrLon to arctan2(c2, c1) + 90. // universal longitude of ascending node
	if c1 > 0 { set xfrLon to xfrLon + 180. }
	local xfrLat to arctan2(c3, sqrt(c1^2 + c2^2)). // geocentric latitude of ascending node
	local az1 is arcsin(cos(i1)/cos(xfrLat)). // azimuth at AN of initial orbit
	local az2 is arcsin(cos(i2)/cos(xfrLat)). // azimuth at AN of final orbit
	if az2 < az1 { set xfrAng to -1 * xfrAng. } // random fix for xfrAng, that I honestly don't know if I even need anymore
	local ta_an to clamp360(xfrLon - ship:obt:argumentofperiapsis - ship:obt:lan).
	if clamp360(ta_an - ship:obt:trueanomaly) > 180 { // use the DN instead of the AN if more than 180 degrees in front
		set ta_an to clamp360(ta_an - 180).
		set xfrAng to -1 * xfrAng.
		verbose("switching to DN").
	}
	local ut_an to time:seconds + getEtaTrueAnomOrbitable(ta_an, ship).
	if liborbit_debug {
		ptp("inclination transfer angle: " + xfrAng).
		print "c1: " + c1.
		print "xfrLon: " + xfrLon.
		print "xfrLat: " + xfrLat.
		print "az1: " + az1.
		print "az2: " + az2.
	}
	return list(ta_an, ut_an, xfrAng).
}

declare function getChangeIncNode {
	declare parameter i2, lan2.
	wait 0.
	local info is getChangeInc(ship:obt:inclination, i2, ship:obt:lan, lan2).
	local ut_an is info[1].
	local xfrAng is info[2].
	ptp("inclination transfer angle: " + xfrAng).
	local r1 to positionat(ship, ut_an) - ship:body:position.
	local v1 to velocityat(ship, ut_an):orbit.
	local v1_h to vxcl(r1, v1).
	local v2_hn to vcrs(r1, v1_h):normalized * (v1_h:mag * sin(xfrAng * -1)).
	local v2_hp to v1_h * cos(xfrAng).
	local v2_h to v2_hn + v2_hp.
	local v_delta to v2_h - v1_h.
	local nd to  getNodeDv(v1, v_delta, r1, ut_an).
	add nd.
	return nd.
}

declare function getInterceptNode {
	declare parameter tgt.
	wait 0.
	local m to 1.
	local rz to tgt:obt:semimajoraxis.
	local a to (rz + ship:obt:semimajoraxis) / 2.
	//local burnoffset to 180 * (1 - (2 * m - 1) * ((a / rz) ^ (3/2))).
	local burnoffset to 180 * (1 - ((a / rz) ^ (3/2))).
	local phaseangle to tgt:obt:lan + tgt:obt:argumentofperiapsis + tgt:obt:trueanomaly - (ship:obt:lan + ship:obt:argumentofperiapsis + ship:obt:trueanomaly).
	// local traverseangle to mod(phaseangle - burnoffset + 3600, 360).  // hack to stop me from getting negative traverse angles
	local traverseangle is clamp360(phaseangle - burnoffset).
	local timetoburn to time:seconds + (traverseangle)/((360/ship:obt:period)-(360/tgt:obt:period)).
	// local timetoburn to time:seconds + getEtaTrueAnom(traverseangle + ship:obt:trueanomaly).
	// local futurepos to positionat(ship, timetoburn).
	// local futuretgt to positionat(tgt, timetoburn).
	// local futuredown to ship:body:position - futurepos.
	local futuredown to ship:body:position - positionat(ship, timetoburn).
	local futurenorm to vcrs(futuredown, velocityat(ship, timetoburn):orbit).
	local futurevel to velocityat(ship, timetoburn):orbit.
	local trnsvel to vcrs(futurenorm, futuredown):normalized * sqrt(ship:body:mu * (2 / futuredown:mag - 1 / a)).
	// local trnsvel is getHoriVelVecAt(timetoburn).
	// set trnsvel:mag to sqrt(ship:body:mu * (2 / futuredown:mag - 1 / a)).
	local nd is getNode(futurevel, trnsvel, futuredown * -1, timetoburn).
	add nd.
	return nd.
}

declare function getInterceptParameters {
	declare parameter origin, tgt.
	local m to 1.
	local rz to tgt:obt:semimajoraxis.
	local a to (rz + origin:obt:semimajoraxis) / 2.
	local mu is origin:body:mu.
	local burnoffset to 180 * (1 - (2 * m - 1) * ((a / rz) ^ (3/2))). // phase angle at time of burn
	local phaseangle is getUniversalLon(tgt) - getUniversalLon(origin).
	local traverseangle is clamp360(phaseangle - burnoffset).
	local meanMotion1 is getMeanMotion(origin:body:mu, origin:obt:semimajoraxis).
	local meanMotion2 is getMeanMotion(tgt:body:mu, tgt:obt:semimajoraxis).
	local timetoburn to time:seconds + (traverseangle)/abs((360/origin:obt:period)-(360/tgt:obt:period)).
	local futuredown to origin:body:position - positionat(origin, timetoburn).
	local transferSpeed is sqrt(mu * (2 / futuredown:mag - 1 / a)).
	local transferDuration is getOrbPer(a, mu) / 2.
	return list(timetoburn, transferSpeed, burnoffset, transferDuration).
}

declare function getInterceptAtPeNode {
	declare parameter tgt.
	local m to 1.
	local rz to tgt:obt:periapsis.
	local a to (rz + ship:obt:semimajoraxis) / 2.
	local dt_travel is getOrbPer(a, ship:body:mu) / 2.
	local dt_arival is getEtaTrueAnomOrbitable(0, tgt).
	local burntime is -1.
	local trnsvel is v(0,0,0).
	if (dt_arival > 4 * dt_travel) {
		local d_tanom is 180 + (ship:obt:lan + ship:obt:argumentofperiapsis) - (tgt:obt:lan + tgt:obt:argumentofperiapsis).
		set burntime to time:seconds + getEtaTrueAnom(d_tanom).
		local rb is ship:body:position - positionat(ship, burntime).
		set trnsvel to getHoriVelVecAt(burntime).
		set trnsvel:mag to getOrbVel(ship:obt:semimajoraxis, a, ship:body:mu).
		local nd1 is getNode(velocityat(ship, burntime), trnsvel, rb, burntime).
		add nd1.
	}
	local burnoffset to 180 * (1 - (2 * m - 1) * ((a / rz) ^ (3/2))).
	local phaseangle to tgt:obt:lan + tgt:obt:argumentofperiapsis + tgt:obt:trueanomaly - (ship:obt:lan + ship:obt:argumentofperiapsis + ship:obt:trueanomaly).
	local traverseangle is clamp360(phaseangle - burnoffset).
	local timetoburn to time:seconds + getEtaTrueAnom(traversangle + ship:obt:trueanomaly).
	local futurepos to positionat(ship, timetoburn).
	local futuretgt to positionat(tgt, timetoburn).
	local futuredown to ship:body:position - futurepos.
	local futurenorm to vcrs(futuredown, velocityat(ship, timetoburn):orbit).
	local futurevel to velocityat(ship, timetoburn):orbit.
	local trnsvel to vcrs(futurenorm, futuredown):normalized * sqrt(ship:body:mu * (2 / futuredown:mag - 1 / a)).
	local burnvel to trnsvel - futurevel.
	local burnangle to vang(burnvel, futurevel).
	if (vang(burnvel, futuredown) < vang(futurevel, futuredown)) set burnangle to burnangle * -1.
	local nd is getNode(futurevel, trnsvel, futuredown * -1, timetoburn).
	add nd.
	return nd.
}

declare function getTAFromOrbitableUt {
	declare parameter ves, ut.
	local t1 is time:seconds.
	local t2 is ut.
	local dt is t2 - t1.
	return getTAFromOrbitableEta(ves, dt).
}

declare function getTAFromOrbitableEta {
	declare parameter ves, dt.
	local ecc is ves:orbit:eccentricity.
	local period is ves:orbit:period.
	local ta1 is ves:orbit:trueanomaly.
	local ea1 is getEAnom(ecc, ta1).
	local ma1 is getMAnom(ecc, ea1).
	local ma2 is clamp360(ma1 + dt * 360 / period).
	local ea2 is approxEAnom(ecc, ma2).
	local ta2 is getTAnom(ecc, ea2).
	return clamp360(ta2).
}

declare function getUniversalLon {
	declare parameter ves.
	// local angle is ves:orbit:argumentofperiapsis + ves:orbit:trueanomaly.
	// local ret is ves:orbit:lan + arctan(cos(ves:orbit:inclination) * tan(angle))).
	// if angle > 90 and angle < 270 set ret to ret + 180.
	return getUniversalLonFromTA(ves, ves:orbit:trueanomaly).
	// return clamp360(ves:orbit:lan + cos(ves:orbit:inclination) * (ves:orbit:argumentofperiapsis + ves:orbit:trueanomaly)).
	// return clamp360(ves:orbit:lan + ves:orbit:argumentofperiapsis + ves:orbit:trueanomaly).
}

declare function getUniversalLonFromTA {
	declare parameter ves, ta.
	local angle is ves:orbit:argumentofperiapsis + ta.
	// print "angle: " + angle.
	local ret is ves:orbit:lan + arctan(cos(ves:orbit:inclination) * tan(angle)).
	if cos(angle) < 0 set ret to ret + 180.
	return clamp360(ret).
	// return clamp360(ves:orbit:lan + cos(ves:orbit:inclination) * (ves:orbit:argumentofperiapsis + ta)).
	// return clamp360(ves:orbit:lan + ves:orbit:argumentofperiapsis + ta).
}

declare function getPhaseAngleAt {
	declare parameter ves, tgt, ut.
	return clamp360(getPhaseAngleAt2(ves, tgt, ut)).
}

declare function getPhaseAngleAt1 {
	declare parameter ves, tgt, ut.
	// This method uses actual position vectors to find the phase angle
	// For vessels in different planes it is possible for vessels with the same
	// universal longitude to show a phase angle, equal to their relative inclination
	local pos_body is ves:body:position.
	local pos_ves is positionat(ves, ut) - pos_body.
	local pos_tgt is positionat(tgt, ut) - pos_body.
	local angle is vang(pos_ves, pos_tgt).
	local normal is vcrs(pos_ves, pos_tgt).
	local fore is vcrs(pos_ves, normal).
	if vang(fore, pos_tgt) > 90 { set angle to -angle. }
	return angle.
}

declare function getPhaseAngleAt2 {
	declare parameter ves, tgt, ut.
	// This method compares universal longitude when calculating phase angle,
	// such that it is plane independant and may require a plane change in order
	// to actually intercept the target
	local vesTa is getTAFromOrbitableUt(ves, ut).
	local tgtTa is getTAFromOrbitableUt(tgt, ut).
	local vesULon is getUniversalLonFromTA(ves, vesTa).
	local tgtULon is getUniversalLonFromTA(tgt, tgtTa).
	return tgtULon - vesULon.
}

function getEtaToPhaseAngle {
	parameter origin, destination, angle.
	local complete is false.
}

declare function getPhaseAngle {
	declare parameter ves, tgt.
	local vesULon is getUniversalLon(ves).
	local tgtULon is getUniversalLon(tgt).
	// print vesULon.
	// print tgtULon.
	return clamp180(tgtULon - vesULon).
}

declare function getCircNodeAt {
	declare parameter ut.
	local rB is positionat(ship, ut) - ship:body:position.
	local vel is getHoriVelVecAt(ut).
	if (liborbit_drawvectors) {
		global horvelVR is vecdrawargs(rB + ship:body:position, vel * 1000, green, "horizontal velocity vector", 1, true).
	}
	set vel:mag to getOrbVel(rB:mag, rB:mag, ship:body:mu).
	local nd is getNode(velocityat(ship, ut):orbit, vel, rB, ut).
	if (liborbit_drawvectors) {
		global velatVR is vecdrawargs(rB + ship:body:position, velocityat(ship, ut):orbit * 1000, red, "velocity vector", 1, true).
	}
	add nd.
	return nd.
}

declare function getApsisNodeAt {
	declare parameter apsis, ut.
	local rB is positionat(ship, ut) - ship:body:position.
	local vel is getHoriVelVecAt(ut).
	if (liborbit_drawvectors) {
		global horvelVR is vecdrawargs(rB + ship:body:position, vel * 1000, green, "horizontal velocity vector", 1, true).
	}
	local a is (apsis + ship:body:radius + rB:mag) / 2.
	set vel:mag to getOrbVel(rB:mag, a, ship:body:mu).
	local nd is getNode(velocityat(ship, ut):orbit, vel, rB, ut).
	if (liborbit_drawvectors) {
		global velatVR is vecdrawargs(rB, velocityat(ship, ut):orbit * 1000, red, "velocity vector", 1, true).
	}
	add nd.
	return nd.
}

declare function getSMANodeAt {
	declare parameter a, ut.
	local rB is positionat(ship, ut) - ship:body:position.
	local vel is getHoriVelVecAt(ut).
	if (liborbit_drawvectors) {
		global horvelVR is vecdrawargs(rB + ship:body:position, vel * 1000, green, "horizontal velocity vector", 1, true).
	}
	set vel:mag to getOrbVel(rB:mag, a, ship:body:mu).
	local nd is getNode(velocityat(ship, ut):orbit, vel, rB, ut).
	if (liborbit_drawvectors) {
		global velatVR is vecdrawargs(rB + ship:body:position, velocityat(ship, ut):orbit * 1000, red, "velocity vector", 1, true).
	}
	add nd.
	return nd.
}

declare function getSmaAopeNodeAt {
	declare parameter sma2, aop2, e2, ut.
	wait 0.
	local r1 is positionat(ship, ut) - ship:body:position.
	local v1 is velocityat(ship, ut):orbit.
	local aop1 is ship:obt:argumentofperiapsis.
	local daop is aop2 - aop1.
	local ta1 is vang(r1, -1 * ship:body:position).
	if ut - time:seconds > ship:obt:period / 2 { set ta1 to -1 * ta1. }
	set ta1 to clamp360(ship:obt:trueanomaly + ta1).
	local ta2 is clamp360(aop1 + ta1 - aop2).
	local fa2 is arctan(tan(ta2)*(1-(r1:mag/(sma2 * (1-e2^2) ) ) ) ). //flight angle (gama in NASA Handbook)
	set fa2 to getOrbFlightPathAng(ta2, e2).
	local v1_h is vxcl(r1, v1).
	local v2_mag is sqrt(ship:body:mu * (2 / r1:mag - 1 / sma2)).
	local v2_h is v1_h:normalized * v2_mag * cos(fa2).
	local v2_v is r1:normalized * v2_mag * sin(fa2).
	local nd is getNode(v1, v2_h + v2_v, r1, ut).
	add nd.
	return nd.
}

declare function hasNextNode {
	if ship = kuniverse:activevessel {
		return hasnode.
	}
	return false.
}

declare function clearNodes {
	//ship:makeactive(). wait 1.
	if ship = kuniverse:activevessel {
		if hasnode {
			until not hasnode {
				remove nextnode.
				wait 0.
			}
		}
	}
}

declare function getAzForInc {
	declare parameter i.
	// cos i = cos Φ sin β
	// print i.
	// print ship:latitude.
	// print cos(ship:latitude).
	// print cos(i).
	// print (cos(i) / cos(ship:latitude)).
	// print arcsin(cos(i) / cos(ship:latitude)).
	local lat is ship:latitude.
	if abs(lat) > abs(i) {
		return lat - i + 90.
		if lat > i { return 0. }
		return 180.
	}
	else if lat < i
	local az is arcsin(clamp(cos(i) / cos(ship:latitude),-1, 1)).
	if (az < 0) { set az to 180 - az. }
	local v_az is heading(az, 0):vector * getOrbVel(ship:altitude + ship:body:radius, ship:altitude + ship:body:radius, ship:body:mu).
	local v_h is vxcl(ship:up:vector, ship:velocity:orbit).
	local v_delta is v_az - v_h.
	local az_adj is arctan2(vdot(v_delta, heading(90,0):vector), vdot(v_delta, ship:north:vector)).
	return az_adj.
}

declare function getAzForInc2 {
	declare parameter i.
	// cos i = cos Φ sin β
	//local az is arcsin(cos(i) / cos(ship:latitude)).
	//if (az < 0) { set az to 180 - az. }
	local az is 0.
	local cosAz is cos(i) / cos(ship:latitude).
	if abs(cosAz) > 1 {
		if (abs(i) < 90) { set az to 90. }
		else { set az to 270. }
	}
	else {
		local afe is arccos(cosAz).
		if (i < 0) { set afe to -1 * afe. }
		set az to clamp360(90-afe).
	}
	//clearvecdraws().
	local v_az is heading(az, 0):vector * getOrbVel(ship:altitude + ship:body:radius, ship:altitude + ship:body:radius, ship:body:mu).
	local v_h is vxcl(ship:up:vector, ship:velocity:orbit).
	local v_e is v_h:mag * sin(az) * heading(90,0):vector.
	local v_n is v_h:mag * cos(az) * ship:north:vector.
	//if (vdot(v_h, v_n) < 0) { set v_n to -1 * v_n. }
	if clamp180(i) < 0 { set v_n to -1 * v_n. }
	if (liborbit_drawvectors) {
		global a_v_e is vecdraw(ship:position, v_az * 10, yellow, "Azimuth Velocity", 1, true).
		global a_v_h is vecdraw(ship:position, v_h * 10, blue, "Horizontal Velocity", 1, true).
		global a_v_e is vecdraw(ship:position, v_e * 10, red, "East Component", 1, true).
		global a_v_n is vecdraw(ship:position, v_n * 10, red, "North Component", 1, true).
	}
	local v_delta is v_az - v_h.
	local az_adj is arctan2(vdot(v_e,heading(90,0):vector), vdot(v_n,ship:north:vector)).
	return az_adj.
}
