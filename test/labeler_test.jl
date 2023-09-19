using NAB

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

@testset "Labler test" begin
    testsetLabels()
    testWindows()
end
