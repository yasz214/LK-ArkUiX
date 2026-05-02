cmake_minimum_required(VERSION 3.5.0)
project(t2s)

if (DEFINED ENV{ARKUIX_SDK_HOME})
    set(NATIVE_INCLUDE_PATH $ENV{ARKUIX_SDK_HOME}/23/arkui-x/engine/lib/include)
else ()
    message(FATAL_ERROR "ARKUIX_SDK_HOME environment variable not set.")
endif ()

include_directories(${NATIVE_INCLUDE_PATH})

add_library(arkui_android SHARED IMPORTED GLOBAL)
set_target_properties(
    arkui_android
    PROPERTIES IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${CMAKE_ANDROID_ARCH_ABI}/libarkui_android.so
)

set(NATIVE_SOURCE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../entry/src/main/cpp)
if(NOT EXISTS ${NATIVE_SOURCE_PATH})
    message(FATAL_ERROR "Path ${NATIVE_SOURCE_PATH} does not exist. Verify the path and try again.")
endif ()

add_library(t2s SHARED ${NATIVE_SOURCE_PATH}/t2s_engine.cpp)

# ✨ 性能优化：-O3 + LTO + gc-sections
target_compile_options(t2s PRIVATE -O3 -flto -ffunction-sections -fdata-sections)

target_link_libraries(t2s PUBLIC arkui_android log)
target_link_options(t2s PRIVATE -flto -Wl,--gc-sections)

add_library(article_parser SHARED ${NATIVE_SOURCE_PATH}/article_parser.cpp)
target_compile_options(article_parser PRIVATE -O3 -flto -ffunction-sections -fdata-sections)
target_link_libraries(article_parser PUBLIC arkui_android log)
target_link_options(article_parser PRIVATE -flto -Wl,--gc-sections)