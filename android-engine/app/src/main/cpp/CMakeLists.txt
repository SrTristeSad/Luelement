cmake_minimum_required(VERSION 3.22.1)
project(luelement_bridge C)

add_library(
    luelement_bridge
    SHARED
    luelement_bridge.c
)

find_library(log-lib log)
find_library(dl-lib dl)

target_link_libraries(
    luelement_bridge
    ${log-lib}
    ${dl-lib}
)
