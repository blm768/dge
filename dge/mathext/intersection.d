module dge.mathext.intersection;

import dge.math;

TraceResult traceAgainstSphere(Vector3 rayStart, Vector3 rayDir, Vector3 spherePos, float radius) {
	auto deltaPos = spherePos - rayStart;
	auto b = -2 * dot(rayDir, deltaPos);
	auto c = deltaPos.magSquared() - radius * radius;
	//Luckily, a = 1.
	auto det = b * b - 4 * c;

	float dist;
	if(det > 0) {
		dist = (-b - sqrt(det)) / 2;
		if(dist < 0) {
			dist = (-b + sqrt(det)) / 2;
		}
	} else {
		return TraceResult(false);
	}

	if(dist > 0) {
		return TraceResult(true, rayDir * dist + rayStart, dist);
	}
	return TraceResult(false);
}

struct TraceResult {
	bool foundIntersection = false;
	Vector3 position;
	float distance;
}


