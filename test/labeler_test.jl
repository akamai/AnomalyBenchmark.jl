function getLabler(windowSize::Float64, probationaryPercent::Float64)
    labeler = NAB.Labeler(windowSize, probationaryPercent)
    data    = DataFrame(
        index     = 1:5,
        timestamp = DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5)
    )

    labeler.setData(data)
    return labeler
end

function testsetLabels()
    labeler       = getLabler(0.1, 0.15)
    trueAnomalies = [DateTime(2017, 1, 3)]

    labeler.setLabels(trueAnomalies)
    @test labeler.labels.label == [false,false,true,false,false]

    labeler.setData(DataFrame(index = 1:5,))
    @test_throws ArgumentError labeler.setLabels(trueAnomalies)
end

function testWindows()
    labeler       = getLabler(0.1, 0.15)
    trueAnomalies = [DateTime(2017, 1, 3)]
    labeler.setLabels(trueAnomalies)
    @test  length(labeler.getWindows()) == 1

    labeler = getLabler(0.1, 1.0)
    @test length(labeler.getWindows()) == 0

    labeler       = getLabler(0.1, 1.0)
    trueAnomalies = [DateTime(2017, 1, 3)]
    labeler.setLabels(trueAnomalies)
    @test_logs (:info,"The first window overlaps with the probationary period, so we're deleting it.") labeler.getWindows()
end

function testConvertAnomalousWindows()
    anomalousWindows = [(DateTime(2017, 1, 3, 10, 1), DateTime(2017, 1, 3, 10, 5)), (DateTime(2017, 1, 3, 10, 58), DateTime(2017, 1, 3, 11, 0))]
    expanded = NAB.convertAnomalousWindowsToTimestamps(anomalousWindows)

    @test collect(DateTime("2017-01-03T10:01:00"):Minute(1):DateTime("2017-01-03T10:05:00")) ∪ [ DateTime("2017-01-03T10:58:00") DateTime("2017-01-03T10:59:00") DateTime("2017-01-03T11:00:00") ] == expanded
end

@testset "Labler test" begin
    testsetLabels()
    testWindows()
    testConvertAnomalousWindows()
end
