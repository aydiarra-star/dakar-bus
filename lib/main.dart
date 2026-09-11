String getStopEstimatedDistance(LatLng userPos, LatLng stopPos) {
  const Distance distance = Distance();
  final double meters = distance.as(LengthUnit.Meter, userPos, stopPos);
  
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
