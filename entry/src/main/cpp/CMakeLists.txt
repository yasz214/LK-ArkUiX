cmake_minimum_required(VERSION 3.5.0)
project(NativeEngines)

# ✨ 性能优化：全局编译选项
# -O3: 最大优化
# -flto: 链接时优化（跨函数内联、死代码消除）
# -ffunction-sections -fdata-sections: 按函数/数据分段，配合 gc-sections 消除未引用代码
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -flto -ffunction-sections -fdata-sections")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -flto -Wl,--gc-sections")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(t2s SHARED t2s_engine.cpp)
target_link_libraries(t2s PUBLIC libace_napi.z.so)
# Force-include bisheng_fix.h to work around BiSheng libc++ bugs
target_compile_options(t2s PRIVATE -include "${CMAKE_CURRENT_SOURCE_DIR}/bisheng_fix.h")
message(STATUS "Source directory: ${CMAKE_SOURCE_DIR}")
message(STATUS "Include directories: ${CMAKE_INCLUDE_PATH}")
set(CMAKE_VERBOSE_MAKEFILE ON)
add_library(article_parser SHARED article_parser.cpp)
target_link_libraries(article_parser PUBLIC libace_napi.z.so)
# Force-include bisheng_fix.h to work around BiSheng libc++ bugs
target_compile_options(article_parser PRIVATE -include "${CMAKE_CURRENT_SOURCE_DIR}/bisheng_fix.h")
# 尝试移除编译参数中多余的 include 路径
string(REPLACE "-I\"D:/Program Files/Huawei/DevEco Studio/sdk/default/hms/native/sysroot/usr/include\"" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")