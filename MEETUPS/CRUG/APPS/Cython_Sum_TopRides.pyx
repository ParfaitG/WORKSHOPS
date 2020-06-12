def sum_rides(x):
    cdef int top_rides = 0
    for i in x:
        top_rides += i

    return top_rides
    

def cum_sum_rides(x):
    cdef int top_rides = 0
    cdef int sum_ride = 0
    cdef int cum_top[10]
    
    for n,i in enumerate(x):
        sum_ride += i
        cum_top[n] = sum_ride
        
    return cum_top
    

