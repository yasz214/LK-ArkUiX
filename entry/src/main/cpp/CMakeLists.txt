cmake_minimum_required(VERSION 3.5.0)
project(NativeEngines)

add_library(t2s SHARED t2s_engine.cpp)
target_link_libraries(t2s PUBLIC libace_napi.z.so)

add_library(article_parser SHARED article_parser.cpp)
target_link_libraries(article_parser PUBLIC libace_napi.z.so)