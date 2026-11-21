/// Width of the screen-edge band reserved for the system back gesture
/// (`v0.1.5 design` §8.9).
const double kSystemEdgeGestureWidth = 20;

/// Whether a horizontal gesture starting at [globalX] belongs to the system
/// edge gesture rather than to the page's own paging or row swipe.
bool isEdgeSwipe(
  double globalX,
  double width, {
  double edge = kSystemEdgeGestureWidth,
}) {
  return globalX <= edge || globalX >= width - edge;
}
