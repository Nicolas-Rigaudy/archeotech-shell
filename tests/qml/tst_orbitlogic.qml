import QtQuick
import QtTest
import "../../Commons/Primitives/OrbitLogic.js" as Orbit

// OrbitViz geometry (Commons/Primitives/OrbitLogic.js). Run: tests/run.sh
TestCase {
    name: "OrbitLogic"

    function test_firstNodeStartsAtTop() {
        var p = Orbit.nodePos(0, 4, 0, 100, 50, 80, 30)
        fuzzyCompare(p.x, 100, 0.001)
        fuzzyCompare(p.y, 20, 0.001)
    }
    function test_nodesEvenlySpaced() {
        var a = Orbit.nodePos(0, 4, 0, 0, 0, 10, 10)
        var b = Orbit.nodePos(1, 4, 0, 0, 0, 10, 10)
        fuzzyCompare(b.x, 10, 0.001)     // quarter turn: top -> right
        fuzzyCompare(b.y, 0, 0.001)
        fuzzyCompare(a.y, -10, 0.001)
    }
    function test_ringTurnsWithTime() {
        var p0 = Orbit.nodePos(0, 4, 0, 0, 0, 10, 10)
        var p1 = Orbit.nodePos(0, 4, 5, 0, 0, 10, 10)
        verify(Math.abs(p0.x - p1.x) > 0.1, "moves over time")
        var full = 1 / Orbit.TURNS_PER_SEC
        var p2 = Orbit.nodePos(0, 4, full, 0, 0, 10, 10)
        fuzzyCompare(p2.x, p0.x, 0.001)  // one whole turn returns
        fuzzyCompare(p2.y, p0.y, 0.001)
    }
    function test_nodePosStaysOnEllipse() {
        var p = Orbit.nodePos(2, 5, 7.3, 0, 0, 60, 20)
        fuzzyCompare((p.x * p.x) / 3600 + (p.y * p.y) / 400, 1, 0.0001)
    }
    function test_nodeRadiusClamped() {
        compare(Orbit.nodeRadius(0, 6, 14), 6)
        compare(Orbit.nodeRadius(100, 6, 14), 14)
        compare(Orbit.nodeRadius(50, 6, 14), 10)
        compare(Orbit.nodeRadius(250, 6, 14), 14, "over 100 clamps")
        compare(Orbit.nodeRadius(-5, 6, 14), 6, "negative clamps")
    }
    function test_strandAlphaFadesWithDistanceAndGrowsWithValue() {
        verify(Orbit.strandAlpha(0, 100, 50) > Orbit.strandAlpha(100, 100, 50))
        verify(Orbit.strandAlpha(50, 100, 90) > Orbit.strandAlpha(50, 100, 10))
        verify(Orbit.strandAlpha(1000, 100, 0) > 0, "never fully off")
        verify(Orbit.strandAlpha(0, 100, 100) <= 1)
    }
    function test_strandPinnedAtBothEnds() {
        var pts = Orbit.strandPoints(10, 20, 110, 70, 3.3, 8, 2, 16)
        compare(pts.length, 17)
        fuzzyCompare(pts[0].x, 10, 0.001);   fuzzyCompare(pts[0].y, 20, 0.001)
        fuzzyCompare(pts[16].x, 110, 0.001); fuzzyCompare(pts[16].y, 70, 0.001)
    }
    function test_strandDisplacementBoundedByAmp() {
        var pts = Orbit.strandPoints(0, 0, 100, 0, 1.1, 6, 1, 20)
        for (var i = 0; i < pts.length; i++) verify(Math.abs(pts[i].y) <= 6.0001)
    }
    function test_zeroAmpIsStraightLine() {
        var pts = Orbit.strandPoints(0, 0, 100, 0, 1.1, 0, 1, 10)
        for (var i = 0; i < pts.length; i++) fuzzyCompare(pts[i].y, 0, 0.0001)
    }
    function test_strandAnimatesWithTime() {
        var a = Orbit.strandPoints(0, 0, 100, 0, 0, 6, 1, 10)
        var b = Orbit.strandPoints(0, 0, 100, 0, 1, 6, 1, 10)
        verify(Math.abs(a[5].y - b[5].y) > 0.01)
    }
    function test_degenerateStrand() {
        compare(Orbit.strandPoints(5, 5, 5, 5, 0, 4, 0, 8).length, 1)
    }
}
