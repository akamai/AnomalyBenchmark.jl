function testFirstTruePositiveWithinWindow()
    """
    First record within window has a score approximately equal to
    costMatrix["tpWeight"]; within 4 decimal places is more than enough
    precision.
    """
    costMatrix = Dict{AbstractString, Float64}(
                    "tpWeight" => 1.0,
                    "fpWeight" => 1.0,
                    "fnWeight" => 1.0,
                    "tnWeight" => 1.0)

    startTimeTime = now()
    increment     = Minute(5)
    len           = 10
    numWindows    = 1
    windowSize    = 2

    timestamps  = generateTimestamps(startTimeTime, increment, len)
    windows     = generateWindows(timestamps, numWindows, windowSize)
    labels      = generateLabels(timestamps, windows)
    predictions = zeros(Int, len)

    index              = findfirst(timestamps .== windows[1][1])
    predictions[index] = 1
    scorer             = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix, 0)
    (_, score)         = scorer.getScore()

    @test score ≈ costMatrix["tpWeight"] rtol=1e-4
    checkCounts(scorer.counts, len-windowSize*numWindows, 1, 0, windowSize*numWindows-1)
end

function testEarlierTruePositiveIsBetter()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    """
    If two algorithms both get a true positive within a window, the algorithm
    with the earlier true positive (in the window) should get a higher score.
    """
    startTime  = DateTime(now())
    increment  = Minute(5)
    len        = 10
    numWindows = 1
    windowSize = 2

    timestamps   = generateTimestamps(startTime, increment, len)
    windows      = generateWindows(timestamps, numWindows, windowSize)
    labels       = generateLabels(timestamps, windows)
    predictions1 = zeros(Int, len)
    predictions2 = zeros(Int, len)
    t1, t2       = windows[1]

    index1               = findfirst(timestamps .== t1)
    predictions1[index1] = 1
    scorer1              = NAB.Scorer(timestamps, predictions1, labels, windows, costMatrix,
      0)
    (_, score1)          = scorer1.getScore()

    index2                = findfirst(timestamps .== t2)
    predictions2[index2]  = 1
    scorer2               = NAB.Scorer(timestamps, predictions2, labels, windows, costMatrix,
      0)
    (_, score2)           = scorer2.getScore()

    @test score1 > score2
    checkCounts(scorer1.counts, len-windowSize*numWindows, 1, 0,
      windowSize*numWindows-1)
    checkCounts(scorer2.counts, len-windowSize*numWindows, 1, 0,
      windowSize*numWindows-1)
end


function testOnlyScoreFirstTruePositiveWithinWindow()
    """
    An algorithm making multiple detections within a window (i.e. true positive)
    should only be scored for the earliest true positive.
    """
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime = DateTime(now())
    increment = Minute(5)
    len = 10
    numWindows = 1
    windowSize = 2

    timestamps = generateTimestamps(startTime, increment, len)
    windows = generateWindows(timestamps, numWindows, windowSize)
    labels = generateLabels(timestamps, windows)
    predictions = zeros(Int, len)
    window = windows[1]
    t1, t2 = window

    index1 = findfirst(timestamps .== t1)
    predictions[index1] = 1
    scorer1 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,
      0)
    (_, score1) = scorer1.getScore()

    index2 = findfirst(timestamps .== t2)
    predictions[index2] = 1
    scorer2 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,
      0)
    (_, score2) = scorer2.getScore()

    @test score1 == score2
    checkCounts(scorer1.counts, len-windowSize*numWindows, 1, 0,
      windowSize*numWindows-1)
    checkCounts(scorer2.counts, len-windowSize*numWindows, 2, 0,
      windowSize*numWindows-2)
end

function testTruePositivesWithDifferentWindowSizes()
    """
    True positives  at the left edge of windows should have the same score
    regardless of width of window.
    """
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime = DateTime(now())
    increment = Minute(5)
    len = 10
    numWindows = 1
    timestamps = generateTimestamps(startTime, increment, len)

    windowSize1 = 2
    windows1 = generateWindows(timestamps, numWindows, windowSize1)
    labels1 = generateLabels(timestamps, windows1)
    index = findfirst(timestamps .== windows1[1][1])
    predictions1 = zeros(Int, len)
    predictions1[index] = 1

    windowSize2 = 3
    windows2 = generateWindows(timestamps, numWindows, windowSize2)
    labels2 = generateLabels(timestamps, windows2)
    index = findfirst(timestamps .== windows2[1][1])
    predictions2 = zeros(Int, len)
    predictions2[index] = 1

    scorer1 = NAB.Scorer(timestamps, predictions1, labels1, windows1,
      costMatrix, 0)
    (_, score1) = scorer1.getScore()
    scorer2 = NAB.Scorer(timestamps, predictions2, labels2, windows2,
      costMatrix, 0)
    (_, score2) = scorer2.getScore()

    @test score1 == score2
    checkCounts(scorer1.counts, len-windowSize1*numWindows, 1, 0,
      windowSize1*numWindows-1)
    checkCounts(scorer2.counts, len-windowSize2*numWindows, 1, 0,
      windowSize2*numWindows-1)
end

function testTruePositiveAtRightEdgeOfWindow()
    """
    True positives at the right edge of a window should yield a score of
    approximately zero; the scaled sigmoid scoring function crosses the zero
    between a given window's last timestamp and the next timestamp (immediately
    following the window.
    """
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime = DateTime(now())
    increment = Minute(5)
    len = 1000
    numWindows = 1
    windowSize = 100

    timestamps = generateTimestamps(startTime, increment, len)
    windows = generateWindows(timestamps, numWindows, windowSize)
    labels = generateLabels(timestamps, windows)
    predictions = zeros(Int, len)

    # Make prediction at end of the window; TP
    index = findfirst(timestamps .== windows[1][2])
    predictions[index] = 1
    scorer1 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,
      0)
    (_, score1) = scorer1.getScore()
    # Make prediction just after the window; FP
    predictions[index] = 0
    index += 1
    predictions[index] = 1
    scorer2 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,
      0)
    (_, score2) = scorer2.getScore()

    # TP score + FP score + 1 should be very close to 0; the 1 is added to
    # account for the subsequent FN contribution.
    @test score1 + score2 + 1 ≈ 0.0 atol=1e-3
    checkCounts(scorer1.counts, len-windowSize*numWindows, 1, 0,
      windowSize*numWindows-1)
    checkCounts(scorer2.counts, len-windowSize*numWindows-1, 0, 1,
      windowSize*numWindows)
end

@testset "True positive test" begin
  testFirstTruePositiveWithinWindow()
  testEarlierTruePositiveIsBetter()
  testOnlyScoreFirstTruePositiveWithinWindow()
  testTruePositivesWithDifferentWindowSizes()
  testTruePositiveAtRightEdgeOfWindow()
end
