function testNullCase()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime = now()
    increment = Minute(5)
    len = 10
    timestamps = generateTimestamps(startTime, increment, len)

    predictions = zeros(Int, len)

    labels = zeros(Int, len)

    windows = missings(Tuple{DateTime, DateTime}, 0)

    scorer = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix, 0)

    scorer.getScore()

    @test scorer.score == 0.0
end

function testFalsePositiveScaling()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime  = now()
    increment  = Minute(5)
    len        = 100
    numWindows = 1
    windowSize = 10

    timestamps = generateTimestamps(startTime, increment, len)
    windows = generateWindows(timestamps, numWindows, windowSize)
    labels = generateLabels(timestamps, windows)

    costMatrix["fpWeight"] = 0.11

    scores = []
    for i in 1:20
        predictions = zeros(Int, len)
        indices = rand(1:len, 10)
        predictions[indices] .= 1
        scorer = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,0)
        scorer.getScore()
        push!(scores, scorer.score)
    end

    @test -1.5 <= mean(scores) <= 0.5
end

function testRewardLowFalseNegatives()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime  = DateTime(1970,1,1)
    increment  = Minute(5)
    len        = 100
    numWindows = 1
    windowSize = 10

    timestamps               = generateTimestamps(startTime, increment, len)
    windows                  = generateWindows(timestamps, numWindows, windowSize)
    labels                   = generateLabels(timestamps, windows)
    predictions              = zeros(Int, len)
    costMatrix["fpWeight"]   = 1.0
    costMatrixFN             = deepcopy(costMatrix)
    costMatrixFN["fnWeight"] = 2.0
    costMatrixFN["fpWeight"] = 0.055

    scorer1 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix,0)
    scorer1.getScore()

    scorer2 = NAB.Scorer(timestamps, predictions, labels, windows, costMatrixFN,0)
    scorer2.getScore()

    @test scorer1.score == 0.5*scorer2.score

    checkCounts(scorer1.counts, len-windowSize*numWindows, 0, 0,windowSize*numWindows)

    checkCounts(scorer2.counts, len-windowSize*numWindows, 0, 0,windowSize*numWindows)
end

function testRewardLowFalsePositives()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime  = DateTime(now())
    increment  = Minute(5)
    len        = 100
    numWindows = 0
    windowSize = 10

    timestamps  = generateTimestamps(startTime, increment, len)
    windows     = missings(Tuple{DateTime, DateTime}, 0)
    labels      = generateLabels(timestamps, windows)
    predictions = zeros(Int, len)

    costMatrixFP             = deepcopy(costMatrix)
    costMatrixFP["fpWeight"] = 2.0
    costMatrixFP["fnWeight"] = 0.5
    # FP
    predictions[1] = 1

    scorer1     = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix, 0)
    (_, score1) = scorer1.getScore()
    scorer2     = NAB.Scorer(timestamps, predictions, labels, windows, costMatrixFP,0)
    (_, score2) = scorer2.getScore()

    @test score1 == 0.5*score2
    checkCounts(scorer1.counts, len-windowSize*numWindows-1, 0, 1, 0)
    checkCounts(scorer2.counts, len-windowSize*numWindows-1, 0, 1, 0)
end

function testScoringAllMetrics()
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0, "tnWeight" => 1.0)

    startTime  = DateTime(now())
    increment  = Minute(5)
    len        = 100
    numWindows = 2
    windowSize = 5

    timestamps  = generateTimestamps(startTime, increment, len)
    windows     = generateWindows(timestamps, numWindows, windowSize)
    labels      = generateLabels(timestamps, windows)
    predictions = zeros(Int, len)

    index                = findfirst(timestamps .== windows[1][1])
    # TP, add'l TP, and FP
    predictions[index]   = 1
    predictions[index+1] = 1
    predictions[index+7] = 1

    scorer     = NAB.Scorer(timestamps, predictions, labels, windows, costMatrix, 0)
    (_, score) = scorer.getScore()

    @test score ≈ -0.9540 rtol=1e-4
    checkCounts(scorer.counts, len-windowSize*numWindows-1, 2, 1, 8)

    @test 2 == length(scorer.windows)
    @test startswith(scorer.windows[1].repr(), "WINDOW id=1, limits: [$(scorer.windows[1].t1), $(scorer.windows[1].t2)], length: 5\nwindow data:\n5×4 DataFrame")
end

function testScoreDataSet()
    labeler = NAB.Labeler(0.1, 0.15)
    data = DataFrame(
        index = 1:5,
        timestamp = DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5)
    )
    trueAnomalies = [DateTime(2017, 1, 2)]

    detectorName = "tester"
    costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0)

    anomalyScores = [0.7, 0.8, 0.5, 0.8, 0.9]
    threshold = 0.75


    ds = NAB.scoreDataSet(labeler, data, trueAnomalies, anomalyScores, threshold, detectorName=detectorName, costMatrix=costMatrix)
    @test "customized" == ds["profileName"]
    @test Dict("tp"=>1,"tn"=>2,"fn"=>0,"fp"=>2) == ds["counts"]
    @test -1.0 == ds["score"]
    @test detectorName == ds["detectorName"]

    ds = NAB.scoreDataSet(labeler, data, trueAnomalies, anomalyScores, threshold, detectorName=detectorName, profileName = "standard")
    @test "standard" == ds["profileName"]
    @test Dict("tp"=>1,"tn"=>2,"fn"=>0,"fp"=>2) == ds["counts"]
    @test 0.78 == ds["score"]
    @test detectorName == ds["detectorName"]

    @test_throws ErrorException NAB.scoreDataSet(labeler, data, trueAnomalies, anomalyScores, threshold, detectorName=detectorName, costMatrix = Dict("tpWeight" => 1.0))
    @test_throws ErrorException NAB.scoreDataSet(labeler, data, trueAnomalies, anomalyScores, threshold, detectorName=detectorName, profileName = "foo")
end

function testNormalizeScore()
    timestamps = collect(DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5))
    predictions = [0, 1, 0, 0, 1]
    labels         = [0, 1, 0, 0, 0]
    windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
    costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
    probationaryPeriod = 1
    scorer = NAB.Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)

    scorer.getScore()

    scorer.normalizeScore()

    @test 50.00454 == round(scorer.normalizedScore, digits=5)
end

"""Ensure the metric counts are correct."""
function checkCounts(counts, tn, tp, fp, fn)
  @test counts["tn"] == tn
  @test counts["tp"] == tp
  @test counts["fp"] == fp
  @test counts["fn"] == fn
end


@testset "Scorer test" begin
    testNullCase()
    testFalsePositiveScaling()
    testRewardLowFalseNegatives()
    testRewardLowFalsePositives()
    testScoringAllMetrics()
    testScoreDataSet()
    testNormalizeScore()
end
