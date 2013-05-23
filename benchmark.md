# profiling server

## on solaris
see <http://blog.nodejs.org/2012/04/25/profiling-node-js/>

    dtrace -n 'profile-97/execname == "node" && arg1/{
        @[jstack(150, 8000)] = count(); } tick-60s { exit(0); }' > stacks.out

by PID:

    dtrace -n 'profile-97/pid == 93690 && arg1/{
        @[jstack(150, 8000)] = count(); } tick-60s { exit(0); }' > stacks.out

Then

    stackvis dtrace flamegraph-svg < stacks.out > stacks.svg

TRAP: this doesn't work on the mac because of some dtrace bug

## using v8

<http://blog.arc90.com/2012/03/05/profiling-node-programs-on-mac-os-x/>

To build node in 32 bit:


Building v8 with scons:

    scons I_know_I_should_build_with_GYP=yes arch=x64 -j12 d8

(otherwise defaults to 32 bit)

Node defaults to 64 bit. to build 32:

    ./configure --dest-cpu ia32  

It works if everything is 64. The v8 has to be exactly the same as the one in the node build. So build it separately

In principle the profiler can be started and stopped. But this module [bnoordhuis/node-profiler  GitHub](https://github.com/bnoordhuis/node-profiler) doesn't work properly. Should be able to do this:


    #!/usr/bin/env coffee --nodejs --prof --nodejs --prof_lazy --nodejs --log

    profiler = require 'profiler'
    profiler.resume()

and see a log, but the logfile contains no code events, so instead the entire program has to be profiled

To see a list of all these v8 flags:

    node --v8-options

To compile the log:

    cd ~proj/javascript/node/installed/node-v0.10.0/deps/v8
    ./tools/mac-tick-processor ~proj/javascript/ace_mvc/v8.log > ~/Desktop/bench.log

# benchmarking server response time

testing total round trip time (including TCP est.) single process

    ab -n 1000 -c 1 http://localhost:1337/

## 2808a9c201e3666eef656220fc703f511945b37c old outlets

    Server Software:        Server Hostname:        localhost
    Server Port:            1337

    Document Path:          /
    Document Length:        906 bytes

    Concurrency Level:      1
    Time taken for tests:   3.565 seconds
    Complete requests:      1000
    Failed requests:        0
    Write errors:           0
    Total transferred:      1004000 bytes
    HTML transferred:       906000 bytes
    Requests per second:    280.49 [#/sec] (mean)
    Time per request:       3.565 [ms] (mean)
    Time per request:       3.565 [ms] (mean, across all concurrent requests)
    Transfer rate:          275.01 [Kbytes/sec] received

    Connection Times (ms)
                  min  mean[+/-sd] median   max
    Connect:        0    0   0.1      0       0
    Processing:     2    3   2.1      3      22
    Waiting:        2    3   2.1      3      22
    Total:          2    4   2.1      3      22

    Percentage of the requests served within a certain time (ms)
      50%      3
      66%      3
      75%      4
      80%      4
      90%      4
      95%      5
      98%      9
      99%     18
     100%     22 (longest request)

## 3db9f39c7fd4033ba1213bf1aa3d06ad2f4476f9 after new outlets

    Server Software:        
    Server Hostname:        localhost
    Server Port:            1338

    Document Path:          /
    Document Length:        896 bytes

    Concurrency Level:      1
    Time taken for tests:   4.030 seconds
    Complete requests:      1000
    Failed requests:        0
    Write errors:           0
    Total transferred:      994000 bytes
    HTML transferred:       896000 bytes
    Requests per second:    248.15 [#/sec] (mean)
    Time per request:       4.030 [ms] (mean)
    Time per request:       4.030 [ms] (mean, across all concurrent requests)
    Transfer rate:          240.88 [Kbytes/sec] received

    Connection Times (ms)
                  min  mean[+/-sd] median   max
    Connect:        0    0   0.1      0       0
    Processing:     3    4   2.2      3      30
    Waiting:        3    4   2.2      3      30
    Total:          3    4   2.2      4      30

    Percentage of the requests served within a certain time (ms)
      50%      4
      66%      4
      75%      4
      80%      4
      90%      5
      95%      5
      98%     13
      99%     17
     100%     30 (longest request)

# Client-side profiling

## 2808a9c201e3666eef656220fc703f511945b37c
CPU profile at </Users/mikerobe/Documents/Local/Dropbox/Documents/all/_+Documents/_Projects/_javascript/ace_mvc/bench/2808a9c201e3666eef656220fc703f511945b37c/CPU-20130523T132941.cpuprofile >

approximately the same runtimes as 3db9f39c7fd4033ba1213bf1aa3d06ad2f4476f9

  - 16 ms load external scripts
  - 18 ms load local
  - 31 ms run program

    - 14.9 ms appendTo
    - 5.7 ms controller build

## 3db9f39c7fd4033ba1213bf1aa3d06ad2f4476f9
CPU profile at </Users/mikerobe/Documents/Local/Dropbox/Documents/all/_+Documents/_Projects/_javascript/ace_mvc/bench/3db9f39c7fd4033ba1213bf1aa3d06ad2f4476f9/CPU-20130523T131036.cpuprofile >

  - 12 ms to load external scripts (jquery sockio)
  - 18 ms to load debug version of own scripts using browserify
  - 26 ms to run them on the page (the restore script)

    - 4 ms to build ace
    - 3.5 ms to enableNavigator (2.3 for the Navigator constructor)
    - 14 ms to appendTo
    - 5 ms each time a controller is built

