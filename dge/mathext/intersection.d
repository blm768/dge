module dge.mathext.intersection;

import dge.math;

TraceResult traceAgainstSphere(Vector3 rayStart, Vector3 rayDir, Vector3 spherePos, float radius) {
	auto deltaPos = spherePos - rayStart;
	auto b = -2 * dot(rayDir, deltaPos);
	auto c = deltaPos.magSquared() - radius * radius;
	//Luckily, a = 1.
	auto det = b * b - 4 * c;

	float du;
	if(det > 0) {
		du = (-b - sqrt(det)) / 2;
		if(du < 0) {
			du = (-b + sqrt(det)) / 2;
		}
	}

	if(du > 0) {
		return TraceResult(true, rayDir * du + rayStart, du);
	}
	return TraceResult(false);
}

struct TraceResult {
	bool foundIntersection = false;
	Vector3 position;
	float distance;
}


