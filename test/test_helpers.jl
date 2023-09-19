"""
Returns a list of numWindows windows, where each window is a pair of
timestamps. Each window contains windowSize intervals. The windows are roughly
evenly spaced throughout the list of timestsamps.

### Arguments

`startTime::DateTime`

`increment::timedelta`
: Time increment(Minute,Second,..)

`len::Int`
: Number of datetime objects
"""
function generateTimestamps(startTime::DateTime, increment, len::Int)
  timestamps = collect(startTime:increment:startTime+len*increment-increment)
  return timestamps
end


"""
Returns a list of numWindows windows, where each window is a pair of
timestamps. Each window contains windowSize intervals. The windows are roughly
evenly spaced throughout the list of timestsamps.

### Arguments

`timestamps::Array{DateTime}`
: (Series) Pandas Series containing list of timestamps.

`numWindows::Int`
: Number of windows to return

`windowSize::Int)`
: Number of 'intervals' in each window. An interval is the duration between the first two timestamps
"""
function generateWindows(timestamps::Array{DateTime}, numWindows::Int, windowSize::Int)

  startTime = timestamps[1]
  delta = timestamps[2] - timestamps[1]
  diff = round(Int, (length(timestamps) - numWindows * windowSize) / float(numWindows + 1))
  windows = missings(Tuple{DateTime, DateTime}, 0)
  for i in 1:numWindows
    t1 = startTime + delta * diff * i + (delta * windowSize * (i - 1))
    t2 = t1 + delta * (windowSize - 1)
    if !(any(timestamps .== t1)) || !(any(timestamps .== t2))
      error("You got the wrong times from the window generator")
    end
    push!(windows, (t1, t2))
  end
  return windows
end


"""
Returns a list of numWindows windows, where each window is a pair of
timestamps. Each window contains windowSize intervals. The windows are roughly
evenly spaced throughout the list of timestsamps.

### Arguments

`timestamps::Array{DateTime}`
: (Series) Pandas Series containing list of timestamps.

`windows::Array(Tuple{DateTime,DateTime},0)`
: Number of windows to return
"""
function generateLabels(timestamps::Array{DateTime}, windows)

  labels = zeros(Int, length(timestamps))
  for (t1, t2) in windows
    subset = t2 .>= timestamps .>= t1
    labels[subset] .= 1
  end
  return labels
end
