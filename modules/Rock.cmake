macro(rock_use_full_rpath install_rpath)
    # use, i.e. don't skip the full RPATH for the build tree
    SET(CMAKE_SKIP_BUILD_RPATH  FALSE)

    # when building, don't use the install RPATH already
    # (but later on when installing)
    SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE) 

    # the RPATH to be used when installing
    SET(CMAKE_INSTALL_RPATH ${install_rpath})

    # add the automatically determined parts of the RPATH
    # which point to directories outside the build tree to the insgall RPATH
    SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endmacro()

function(rock_add_compiler_flag_if_it_exists FLAG)
    string(REGEX REPLACE "[^a-zA-Z]"
        "_" VAR_SUFFIX
        "${FLAG}")
    CHECK_CXX_COMPILER_FLAG(${FLAG} CXX_SUPPORTS${VAR_SUFFIX})
    if (CXX_SUPPORTS${VAR_SUFFIX})
        add_definitions(${FLAG})
    endif()
endfunction()

## Main initialization for Rock CMake projects
macro (rock_init PROJECT_NAME PROJECT_VERSION)
    project(${PROJECT_NAME})
    set(PROJECT_VERSION ${PROJECT_VERSION})
    rock_use_full_rpath("${CMAKE_INSTALL_PREFIX}/lib")

    include(CheckCXXCompilerFlag)
    include(FindPkgConfig)
    rock_add_compiler_flag_if_it_exists(-Wall)
    rock_add_compiler_flag_if_it_exists(-Wno-unused-local-typedefs)
    add_definitions(-DBASE_LOG_NAMESPACE=${PROJECT_NAME})

    IF(APPLE)
        set(CMAKE_SHARED_MODULE_SUFFIX ".bundle")
        set(CMAKE_MACOSX_RPATH 1)
    ENDIF(APPLE)

    if (ROCK_TEST_ENABLED)
        enable_testing()
    endif()
endmacro()

# Allow for a global include dir schema by creating symlinks into the source directory
# Manipulation of the source directory is prevented using individual export
# directories (e.g. to prevent creating files within already symlinked directories)
function(rock_export_includedir DIR TARGET_DIR)
    string(REGEX REPLACE / "-" TARGET_INCLUDE_DIR ${TARGET_DIR})
    set(_ROCK_ADD_INCLUDE_DIR ${PROJECT_BINARY_DIR}/include/_${TARGET_INCLUDE_DIR}_)
    set(_ROCK_EXPORT_INCLUDE_DIR ${_ROCK_ADD_INCLUDE_DIR}/${TARGET_DIR})
    if(NOT EXISTS ${_ROCK_EXPORT_INCLUDE_DIR})
        #get the subdir of the export path
        get_filename_component(_ROCK_EXPORT_INCLUDE_SUBDIR ${_ROCK_EXPORT_INCLUDE_DIR} PATH)

        # Making sure we create all required parent directories
        file(MAKE_DIRECTORY ${_ROCK_EXPORT_INCLUDE_SUBDIR})

        execute_process(COMMAND cmake -E create_symlink ${DIR} ${_ROCK_EXPORT_INCLUDE_DIR})
        if(NOT EXISTS ${_ROCK_EXPORT_INCLUDE_DIR})
            message(FATAL_ERROR "Export include dir '${DIR}' to '${_ROCK_EXPORT_INCLUDE_DIR}' failed")
        endif()
    else()
        message(STATUS "Export include dir: '${_ROCK_EXPORT_INCLUDE_DIR}' already exists")
    endif()
    include_directories(BEFORE ${_ROCK_ADD_INCLUDE_DIR})
endfunction()

function(rock_add_source_dir DIR TARGET_DIR)
    if(IS_ABSOLUTE ${DIR})
        rock_export_includedir(${DIR} ${TARGET_DIR})
    else()
        rock_export_includedir(${CMAKE_CURRENT_SOURCE_DIR}/${DIR}
        ${TARGET_DIR})
    endif()
    add_subdirectory(${DIR})
endfunction()

function(rock_add_dummy_target_dependency TARGET)
    if (NOT TARGET ${TARGET})
        add_custom_target(${TARGET})
    endif()
    add_dependencies(${TARGET} ${ARGN})
endfunction()

macro(rock_doxygen)
    find_package(Doxygen)
    if (DOXYGEN_FOUND)
        if (DOXYGEN_DOT_EXECUTABLE)
            SET(DOXYGEN_DOT_FOUND YES)
        elSE(DOXYGEN_DOT_EXECUTABLE)
            SET(DOXYGEN_DOT_FOUND NO)
            SET(DOXYGEN_DOT_EXECUTABLE "")
        endif(DOXYGEN_DOT_EXECUTABLE)
        configure_file(Doxyfile.in Doxyfile @ONLY)
        add_custom_target(cxx-doc doxygen Doxyfile)
        rock_add_dummy_target_dependency(doc cxx-doc)
    endif(DOXYGEN_FOUND)
endmacro()

macro(rock_standard_layout)
    if (EXISTS ${PROJECT_SOURCE_DIR}/Doxyfile.in)
        rock_doxygen()
    endif()

    if(IS_DIRECTORY ${PROJECT_SOURCE_DIR}/src)
        rock_add_source_dir(src ${PROJECT_NAME})
    endif()

    # Test for known types of Rock subprojects
    if(IS_DIRECTORY ${PROJECT_SOURCE_DIR}/viz)
        option(ROCK_VIZ_ENABLED "set to OFF to disable the visualization plugin. Visualization plugins are automatically disabled if Rock's vizkit3d is not available" ON)
        if (ROCK_VIZ_ENABLED)
            if ("${PROJECT_NAME}" STREQUAL vizkit3d)
                add_subdirectory(viz)
            else()
                rock_find_pkgconfig(vizkit3d vizkit3d)
                if (vizkit3d_FOUND)
                    message(STATUS "vizkit3d found ... building the vizkit3d plugin")
                    rock_add_source_dir(viz vizkit3d)
                else()
                    message(STATUS "vizkit3d not found ... NOT building the vizkit3d plugin")
                endif()
            endif()
        else()
            message(STATUS "visualization plugins disabled as ROCK_VIZ_ENABLED is set to OFF")
        endif()
    endif()

    if (IS_DIRECTORY ${PROJECT_SOURCE_DIR}/ruby)
        if (EXISTS ${PROJECT_SOURCE_DIR}/ruby/CMakeLists.txt)
            include(RockRuby)
            if (RUBY_FOUND)
                add_subdirectory(ruby)
            endif()
        endif()
    endif()

    if (IS_DIRECTORY ${PROJECT_SOURCE_DIR}/bindings/ruby)
        if (EXISTS ${PROJECT_SOURCE_DIR}/bindings/ruby/CMakeLists.txt)
            include(RockRuby)
            if (RUBY_FOUND)
                add_subdirectory(bindings/ruby)
            endif()
        endif()
    endif()

    if (IS_DIRECTORY ${PROJECT_SOURCE_DIR}/configuration)
	install(DIRECTORY ${PROJECT_SOURCE_DIR}/configuration/ DESTINATION configuration/${PROJECT_NAME}
	        FILES_MATCHING PATTERN "*" 
	                       PATTERN "*.pc" EXCLUDE)
    endif()

    if (IS_DIRECTORY ${PROJECT_SOURCE_DIR}/test)
        option(ROCK_TEST_ENABLED "set to OFF to disable the unit tests. Tests are automatically disabled if the boost unit test framework is not available" ON)
        if (ROCK_TEST_ENABLED)
            find_package(Boost COMPONENTS unit_test_framework system)
            if (Boost_UNIT_TEST_FRAMEWORK_FOUND)
                message(STATUS "boost/test found ... building the test suite")
                add_subdirectory(test)
            else()
                message(STATUS "boost/test not found ... NOT building the test suite")
            endif()
        else()
            message(STATUS "unit tests disabled as ROCK_TEST_ENABLED is set to OFF")
        endif()
    endif()
endmacro()

## Like pkg_check_modules, but calls include_directories and link_directories
# using the resulting information
macro (rock_find_pkgconfig VARIABLE)
    if (NOT ${VARIABLE}_FOUND)
        pkg_check_modules(${VARIABLE} ${ARGN})
        foreach(${VARIABLE}_lib ${${VARIABLE}_LIBRARIES})
          set(_${VARIABLE}_lib NOTFOUND)
          find_library(_${VARIABLE}_lib NAMES ${${VARIABLE}_lib} HINTS ${${VARIABLE}_LIBRARY_DIRS})
          if (NOT _${VARIABLE}_lib)
            set(_${VARIABLE}_lib ${${VARIABLE}_lib})
          endif()
          list(APPEND _${VARIABLE}_LIBRARIES ${_${VARIABLE}_lib})
        endforeach()
        list(APPEND _${VARIABLE}_LIBRARIES ${${VARIABLE}_LDFLAGS_OTHER})
        set(${VARIABLE}_LIBRARIES ${_${VARIABLE}_LIBRARIES} CACHE INTERNAL "")
    endif()

    add_definitions(${${VARIABLE}_CFLAGS_OTHER})
    include_directories(${${VARIABLE}_INCLUDE_DIRS})
endmacro()

## Like find_package, but calls include_directories and link_directories using
# the resulting information
macro (rock_find_cmake VARIABLE)
    find_package(${VARIABLE} ${ARGN})
    rock_add_plain_dependency(${VARIABLE})
endmacro()

macro (rock_add_plain_dependency VARIABLE)
    string(TOUPPER ${VARIABLE} UPPER_VARIABLE)

    # Normalize uppercase / lowercase
    foreach(__varname CFLAGS INCLUDE_DIRS INCLUDE_DIR LIBRARY_DIRS LIBRARY_DIR LIBRARIES)
        if (NOT ${VARIABLE}_${__varname})
            set(${VARIABLE}_${__varname} "${${UPPER_VARIABLE}_${__varname}}")
        endif()
    endforeach()

    # Normalize plural/singular
    foreach(__varname INCLUDE_DIR LIBRARY_DIR)
        if (NOT ${VARIABLE}_${__varname}S)
            set(${VARIABLE}_${__varname}S "${${VARIABLE}_${__varname}}")
        endif()
    endforeach()

    # Be consistent with pkg-config
    set(${VARIABLE}_CFLAGS_OTHER ${${VARIABLE}_CFLAGS})

    add_definitions(${${VARIABLE}_CFLAGS_OTHER})
    include_directories(${${VARIABLE}_INCLUDE_DIRS})
    link_directories(${${VARIABLE}_LIBRARY_DIRS})
endmacro()

macro (rock_find_qt4) 
    find_package(Qt4 REQUIRED QtCore QtGui QtOpenGl ${ARGN})
    include_directories(${QT_HEADERS_DIR})
    foreach(__qtmodule__ QtCore QtGui QtOpenGl ${ARGN})
        string(TOUPPER ${__qtmodule__} __qtmodule__)
        add_definitions(${QT_${__qtmodule__}_DEFINITIONS})
        include_directories(${QT_${__qtmodule__}_INCLUDE_DIR})
        link_directories(${QT_${__qtmodule__}_LIBRARY_DIR})
    endforeach()
endmacro()

## Common parsing of parameters for all the C/C++ target types
macro(rock_target_definition TARGET_NAME)
    set(${TARGET_NAME}_INSTALL ON)
    set(ROCK_TARGET_AVAILABLE_MODES "SOURCES;HEADERS;DEPS;DEPS_PKGCONFIG;DEPS_CMAKE;DEPS_PLAIN;MOC;UI;LIBS")

    set(${TARGET_NAME}_MODE "SOURCES")
    foreach(ELEMENT ${ARGN})
        list(FIND ROCK_TARGET_AVAILABLE_MODES "${ELEMENT}" IS_KNOWN_MODE)
        if ("${ELEMENT}" STREQUAL "LIBS")
            set(${TARGET_NAME}_MODE DEPENDENT_LIBS)
        elseif (IS_KNOWN_MODE GREATER -1)
            set(${TARGET_NAME}_MODE "${ELEMENT}")
        elseif("${ELEMENT}" STREQUAL "NOINSTALL")
            set(${TARGET_NAME}_INSTALL OFF)
        else()
            list(APPEND ${TARGET_NAME}_${${TARGET_NAME}_MODE} "${ELEMENT}")
        endif()
    endforeach()

    foreach (internal_dep ${${TARGET_NAME}_DEPS})
        foreach(dep_mode PLAIN CMAKE PKGCONFIG)
            get_property(internal_dep_DEPS TARGET ${internal_dep}
                PROPERTY DEPS_PUBLIC_${dep_mode})

            if (internal_dep_DEPS)
                list(APPEND ${TARGET_NAME}_DEPS_${dep_mode} ${internal_dep_DEPS})
            else()
                get_property(internal_dep_DEPS TARGET ${internal_dep}
                    PROPERTY DEPS_${dep_mode})
                list(APPEND ${TARGET_NAME}_DEPS_${dep_mode} ${internal_dep_DEPS})
            endif()
        endforeach()
    endforeach()
    
    foreach (plain_pkg ${${TARGET_NAME}_DEPS_PLAIN} ${${TARGET_NAME}_PUBLIC_PLAIN})
        rock_add_plain_dependency(${plain_pkg})
    endforeach()
    foreach (pkgconfig_pkg ${${TARGET_NAME}_DEPS_PKGCONFIG} ${${TARGET_NAME}_PUBLIC_PKGCONFIG})
        rock_find_pkgconfig(${pkgconfig_pkg}_PKGCONFIG REQUIRED ${pkgconfig_pkg})
    endforeach()
    foreach (cmake_pkg ${${TARGET_NAME}_DEPS_CMAKE} ${${TARGET_NAME}_PUBLIC_CMAKE})
        rock_find_cmake(${cmake_pkg} REQUIRED)
    endforeach()

    # At this stage, if the user did not set public dependency lists
    # explicitely, pass on everything
    foreach(__depmode PLAIN CMAKE PKGCONFIG)
        if (NOT ${TARGET_NAME}_PUBLIC_${__depmode})
            set(${TARGET_NAME}_PUBLIC_${__depmode} ${${TARGET_NAME}_DEPS_${__depmode}})
        endif()
    endforeach()

    # Export public dependencies to pkg-config
    set(${TARGET_NAME}_PKGCONFIG_REQUIRES
        "${${TARGET_NAME}_PKGCONFIG_REQUIRES} ${${TARGET_NAME}_PUBLIC_PKGCONFIG}")
    string(REPLACE ";" " " ${TARGET_NAME}_PKGCONFIG_REQUIRES "${${TARGET_NAME}_PKGCONFIG_REQUIRES}")
    foreach(dep_mode PLAIN CMAKE)
        foreach(__dep ${${TARGET_NAME}_PUBLIC_${dep_mode}})
            rock_libraries_for_pkgconfig(${TARGET_NAME}_PKGCONFIG_LIBS
                ${${__dep}_LIBRARIES})
            set(${TARGET_NAME}_PKGCONFIG_CFLAGS
                "${${TARGET_NAME}_PKGCONFIG_CFLAGS} ${${__dep}_CFLAGS_OTHER}")
            foreach(__dep_incdir ${${__dep}_INCLUDE_DIRS})
                set(${TARGET_NAME}_PKGCONFIG_CFLAGS
                    "${${TARGET_NAME}_PKGCONFIG_CFLAGS} -I${__dep_incdir}")
            endforeach()
        endforeach()
    endforeach()

    list(LENGTH ${TARGET_NAME}_MOC QT_SOURCE_LENGTH)
    if (QT_SOURCE_LENGTH GREATER 0)
        rock_find_qt4()
        list(APPEND ${TARGET_NAME}_DEPENDENT_LIBS ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY}) 

        set(__${TARGET_NAME}_MOC "${${TARGET_NAME}_MOC}")
        set(${TARGET_NAME}_MOC "")

        set(__cpp_extensions ".c" ".cpp" ".cxx" ".cc")

        # If a source file (*.c*) is listed in MOC, add it to the list of
        # sources and moc the corresponding header
        foreach(__moced_file ${__${TARGET_NAME}_MOC})
            get_filename_component(__file_ext ${__moced_file} EXT)
            list(FIND __cpp_extensions "${__file_ext}" __file_is_source)
            if (__file_is_source GREATER -1)
                list(APPEND ${TARGET_NAME}_SOURCES ${__moced_file})
                get_filename_component(__file_wext ${__moced_file} NAME_WE)
                get_filename_component(__file_dir ${__moced_file} PATH)
                if (NOT "${__file_dir}" STREQUAL "")
		    set(__file_wext "${__file_dir}/${__file_wext}")
                endif()
		unset(__moced_file)
		foreach(__header_ext .h .hh .hxx .hpp)
		    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${__file_wext}${__header_ext}")
			set(__moced_file "${__file_wext}${__header_ext}")
		    endif()
		endforeach()
            endif()
            list(APPEND ${TARGET_NAME}_MOC ${__moced_file})
        endforeach()
         
        QT4_WRAP_CPP(${TARGET_NAME}_MOC_SRCS ${${TARGET_NAME}_MOC})
        list(APPEND ${TARGET_NAME}_SOURCES ${${TARGET_NAME}_MOC_SRCS})

        list(LENGTH ${TARGET_NAME}_UI QT_UI_LENGTH)
        if (QT_UI_LENGTH GREATER 0)
            rock_find_qt4()
            QT4_WRAP_UI(${TARGET_NAME}_UI_HDRS ${${TARGET_NAME}_UI})
            include_directories(${CMAKE_CURRENT_BINARY_DIR})
            list(APPEND ${TARGET_NAME}_SOURCES ${${TARGET_NAME}_UI_HDRS})
        endif()
    endif()
endmacro()

## Common post-target-definition setup for all C/C++ targets
macro(rock_target_setup TARGET_NAME)
    set_property(TARGET ${TARGET_NAME}
        PROPERTY DEPS_PUBLIC_PKGCONFIG ${${TARGET_NAME}_PUBLIC_PKGCONFIG})
    set_property(TARGET ${TARGET_NAME}
        PROPERTY DEPS_PUBLIC_PLAIN ${${TARGET_NAME}_PUBLIC_PLAIN})
    set_property(TARGET ${TARGET_NAME}
        PROPERTY DEPS_PUBLIC_CMAKE ${${TARGET_NAME}_PUBLIC_CMAKE})

    foreach (plain_dep ${${TARGET_NAME}_DEPS_PLAIN})
        target_link_libraries(${TARGET_NAME} ${${plain_dep}_LIBRARIES}
            ${${plain_dep}_LIBRARY})
    endforeach()
    foreach (pkgconfig_pkg ${${TARGET_NAME}_DEPS_PKGCONFIG})
        target_link_libraries(${TARGET_NAME} ${${pkgconfig_pkg}_PKGCONFIG_LIBRARIES})
    endforeach()
    foreach (imported_dep ${${TARGET_NAME}_IMPORTED_DEPS})
        target_link_libraries(${TARGET_NAME} ${${imported_dep}_LIBRARIES})
    endforeach()
    target_link_libraries(${TARGET_NAME} ${${TARGET_NAME}_DEPS})
    target_link_libraries(${TARGET_NAME} ${${TARGET_NAME}_DEPENDENT_LIBS})
    foreach (cmake_pkg ${${TARGET_NAME}_DEPS_CMAKE})
        string(TOUPPER ${cmake_pkg} UPPER_cmake_pkg)
        target_link_libraries(${TARGET_NAME} ${${cmake_pkg}_LIBRARIES} ${${cmake_pkg}_LIBRARY})
        target_link_libraries(${TARGET_NAME} ${${UPPER_cmake_pkg}_LIBRARIES} ${${UPPER_cmake_pkg}_LIBRARY})
    endforeach()
endmacro()

## Defines a new C++ executable
#
# rock_executable(name
#     SOURCES source.cpp source1.cpp ...
#     [DEPS target1 target2 target3]
#     [DEPS_PKGCONFIG pkg1 pkg2 pkg3]
#     [DEPS_CMAKE pkg1 pkg2 pkg3]
#     [MOC qtsource1.hpp qtsource2.hpp])
#     [UI qt_window.ui qt_widget.ui]
#
# Creates a C++ executable and (optionally) installs it
#
# The following arguments are mandatory:
#
# SOURCES: list of the C++ sources that should be built into that library
#
# The following optional arguments are available:
#
# DEPS: lists the other targets from this CMake project against which the
# library should be linked
# DEPS_PKGCONFIG: list of pkg-config packages that the library depends upon. The
# necessary link and compilation flags are added
# DEPS_CMAKE: list of packages which can be found with CMake's find_package,
# that the library depends upon. It is assumed that the Find*.cmake scripts
# follow the cmake accepted standard for variable naming
# MOC: if the library is Qt-based, this is a list of either source or header
# files of classes that need to be passed through Qt's moc compiler.  If headers
# are listed, these headers should be processed by moc, with the resulting
# implementation files are built into the library. If they are source files,
# they get added to the library and the corresponding header file is passed to
# moc.
# UI: if the library is Qt-based, a list of ui files (only active if moc files are
# present)
function(rock_executable TARGET_NAME)
    rock_target_definition(${TARGET_NAME} ${ARGN})

    add_executable(${TARGET_NAME} ${${TARGET_NAME}_SOURCES})
    rock_target_setup(${TARGET_NAME})

    if (${TARGET_NAME}_INSTALL)
        install(TARGETS ${TARGET_NAME}
            RUNTIME DESTINATION bin)
    endif()
endfunction()

# Trigger the configuration of the pkg-config config file (*.pc.in)
# Second option allows to select installation of the generated .pc file
function(rock_prepare_pkgconfig TARGET_NAME DO_INSTALL)
    foreach(pkgname ${${TARGET_NAME}_PUBLIC_PKGCONFIG})
        set(DEPS_PKGCONFIG "${DEPS_PKGCONFIG} ${pkgname}")
    endforeach()
    set(PKGCONFIG_REQUIRES ${${TARGET_NAME}_PKGCONFIG_REQUIRES})
    set(PKGCONFIG_CFLAGS ${${TARGET_NAME}_PKGCONFIG_CFLAGS})
    set(PKGCONFIG_LIBS ${${TARGET_NAME}_PKGCONFIG_LIBS})

    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_NAME}.pc.in)
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_NAME}.pc.in
            ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.pc @ONLY)
        if (DO_INSTALL)
            install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.pc
                DESTINATION lib/pkgconfig)
        endif()
    else()
        message("pkg-config: ${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_NAME}.pc.in is not available for configuration")
    endif()
endfunction()

## Common setup for libraries in Rock. Used by rock_library and
# rock_vizkit_plugin
macro(rock_library_common TARGET_NAME LIB_TYPE)
    rock_target_definition(${TARGET_NAME} ${ARGN})
    # Skip the add_library part if the only thing the caller wants is to install
    # headers
    list(LENGTH ${TARGET_NAME}_SOURCES __source_list_size)
    if (__source_list_size)
        add_library(${TARGET_NAME} ${LIB_TYPE} ${${TARGET_NAME}_SOURCES})
        rock_target_setup(${TARGET_NAME})
        set(${TARGET_NAME}_LIBRARY_HAS_TARGET TRUE)
    endif()
    rock_prepare_pkgconfig(${TARGET_NAME} ${TARGET_NAME}_INSTALL)
endmacro()

# Install list of headers and keep directory structure
function(rock_install_headers HEADER_LIST)
    # Note: using ARGV here, since it expand to the full argument list,
    # otherwise the function would need to be called with a quoted list, e.g.
    # rock_install_headers("${MY_LIST}")
    foreach(HEADER ${ARGV})
        string(REGEX MATCH "(.*)[/\\]" DIR ${HEADER})
        install(FILES ${HEADER} DESTINATION include/${PROJECT_NAME}/${DIR})
    endforeach(HEADER)
endfunction()

## Defines a new shared library
#
# rock_library(name
#     SOURCES source.cpp source1.cpp ...
#     [DEPS target1 target2 target3]
#     [DEPS_PKGCONFIG pkg1 pkg2 pkg3]
#     [DEPS_CMAKE pkg1 pkg2 pkg3]
#     [HEADERS header1.hpp header2.hpp header3.hpp ...]
#     [MOC qtsource1.hpp qtsource2.hpp]
#     [UI qt_window.ui qt_widget.ui]
#     [NOINSTALL])
#
# Creates and (optionally) installs a shared library.
#
# As with all rock libraries, the target must have a pkg-config file along, that
# gets generated and (optionally) installed by the macro. The pkg-config file
# needs to be in the same directory and called <name>.pc.in
# 
# The following arguments are mandatory:
#
# SOURCES: list of the C++ sources that should be built into that library
#
# The following optional arguments are available:
#
# DEPS: lists the other targets from this CMake project against which the
# library should be linked
# DEPS_PKGCONFIG: list of pkg-config packages that the library depends upon. The
# necessary link and compilation flags are added
# DEPS_CMAKE: list of packages which can be found with CMake's find_package,
# that the library depends upon. It is assumed that the Find*.cmake scripts
# follow the cmake accepted standard for variable naming
# HEADERS: a list of headers that should be installed with the library. They get
# installed in include/project_name
# MOC: if the library is Qt-based, a list of either source or header files.
# If headers are listed, these headers should be processed by moc, with the
# resulting implementation files are built into the library. If they are source
# files, they get added to the library and the corresponding header file is
# passed to moc.
# UI: if the library is Qt-based, a list of ui files (only active if moc files are 
# present)
# NOINSTALL: by default, the library gets installed on 'make install'. If this
# argument is given, this is turned off
function(rock_library TARGET_NAME)
    rock_library_common(${TARGET_NAME} SHARED ${ARGN})

    if (${TARGET_NAME}_INSTALL)
        if (${TARGET_NAME}_LIBRARY_HAS_TARGET)
            install(TARGETS ${TARGET_NAME}
                LIBRARY DESTINATION lib
                # On Windows the dll part of a library is treated as RUNTIME target
                # and the corresponding import library is treated as ARCHIVE target
                ARCHIVE DESTINATION lib
                RUNTIME DESTINATION bin)
        endif()

        # Install headers and keep directory structure
        if(${TARGET_NAME}_HEADERS)
            rock_install_headers(${${TARGET_NAME}_HEADERS})
        endif()
    endif()
endfunction()

## Defines a new vizkit3d plugin
#
# rock_vizkit_plugin(name
#     SOURCES source.cpp source1.cpp ...
#     [DEPS target1 target2 target3]
#     [DEPS_PKGCONFIG pkg1 pkg2 pkg3]
#     [DEPS_CMAKE pkg1 pkg2 pkg3]
#     [HEADERS header1.hpp header2.hpp header3.hpp ...]
#     [MOC qtsource1.hpp qtsource2.hpp]
#     [NOINSTALL])
#
# Creates and (optionally) installs a shared library that defines a vizkit3d
# plugin. In Rock, vizkit3d is the base for data display. Vizkit plugins are
# plugins to the 3D display in vizkit3d.
#
# The library gets linked against the vizkit3d libraries automatically (no
# need to list them in DEPS_PKGCONFIG). Moreoer, unlike with a normal shared
# library, the headers get installed in include/vizkit3d
# 
# The following arguments are mandatory:
#
# SOURCES: list of the C++ sources that should be built into that library
#
# The following optional arguments are available:
#
# DEPS: lists the other targets from this CMake project against which the
# library should be linked
# DEPS_PKGCONFIG: list of pkg-config packages that the library depends upon. The
# necessary link and compilation flags are added
# DEPS_CMAKE: list of packages which can be found with CMake's find_package,
# that the library depends upon. It is assumed that the Find*.cmake scripts
# follow the cmake accepted standard for variable naming
# HEADERS: a list of headers that should be installed with the library. They get
# installed in include/project_name
# MOC: if the library is Qt-based, a list of either source or header files.
# If headers are listed, these headers should be processed by moc, with the
# resulting implementation files are built into the library. If they are source
# files, they get added to the library and the corresponding header file is
# passed to moc.
# NOINSTALL: by default, the library gets installed on 'make install'. If this
# argument is given, this is turned off
function(rock_vizkit_plugin TARGET_NAME)
    if (${PROJECT_NAME} STREQUAL "vizkit3d")
    else()
        list(APPEND additional_deps DEPS_PKGCONFIG vizkit3d)
    endif()
    rock_library_common(${TARGET_NAME} MODULE ${ARGN} ${additional_deps})
    if (${TARGET_NAME}_INSTALL)
        if (${TARGET_NAME}_LIBRARY_HAS_TARGET)
            install(TARGETS ${TARGET_NAME}
                LIBRARY DESTINATION lib)
        endif()
        install(FILES ${${TARGET_NAME}_HEADERS}
            DESTINATION include/vizkit3d)
        install(FILES vizkit_plugin.rb
            DESTINATION lib/qt/designer/widgets
            RENAME ${PROJECT_NAME}_vizkit.rb
            OPTIONAL)
    endif()
endfunction()

## Defines a new vizkit widget
#
# rock_vizkit_widget(name
#     SOURCES source.cpp source1.cpp ...
#     [DEPS target1 target2 target3]
#     [DEPS_PKGCONFIG pkg1 pkg2 pkg3]
#     [DEPS_CMAKE pkg1 pkg2 pkg3]
#     [HEADERS header1.hpp header2.hpp header3.hpp ...]
#     [MOC qtsource1.hpp qtsource2.hpp]
#     [NOINSTALL])
#
# Creates and (optionally) installs a shared library that defines a vizkit
# widget. In Rock, vizkit is the base for data display. Vizkit widgets are
# Qt designer widgets that can be seamlessly integrated in the vizkit framework.
#
# If a file called <project_name>.rb exists, it is assumed to be a ruby
# extension used to extend the C++ interface in ruby scripting. It gets
# installed in share/vizkit/ext, where vizkit is looking for it. if a file
# called vizkit_widget.rb exists it will be renamed and installed to
# lib/qt/designer/cplusplus_extensions/<project_name>_vizkit.rb
# 
# List all libraries to link to in the DEPS_PKGCONFIG, including Qt-libraries
# like QtCore. Unlike with a normal shared library, the headers get installed
# in include/<project_name>
# 
# The following arguments are mandatory:
#
# SOURCES: list of the C++ sources that should be built into that library
# MOC: if the library is Qt-based, a list of either source or header files.
# If headers are listed, these headers should be processed by moc, with the
# resulting implementation files are built into the library. If they are source
# files, they get added to the library and the corresponding header file is
# passed to moc.
#
# The following optional arguments are available:
#
# DEPS: lists the other targets from this CMake project against which the
# library should be linked
# DEPS_PKGCONFIG: list of pkg-config packages that the library depends upon. The
# necessary link and compilation flags are added
# DEPS_CMAKE: list of packages which can be found with CMake's find_package,
# that the library depends upon. It is assumed that the Find*.cmake scripts
# follow the cmake accepted standard for variable naming
# HEADERS: a list of headers that should be installed with the library. They get
# installed in include/project_name
# NOINSTALL: by default, the library gets installed on 'make install'. If this
# argument is given, this is turned off
function(rock_vizkit_widget TARGET_NAME)
    rock_library_common(${TARGET_NAME} MODULE ${ARGN})
    if (${TARGET_NAME}_INSTALL)
        install(TARGETS ${TARGET_NAME}
            LIBRARY DESTINATION lib/qt/designer)
        install(FILES ${${TARGET_NAME}_HEADERS}
            DESTINATION include/${PROJECT_NAME})
        install(FILES ${TARGET_NAME}.rb
            DESTINATION share/vizkit/ext
            OPTIONAL)
        install(FILES vizkit_widget.rb
            DESTINATION lib/qt/designer/cplusplus_extensions
            RENAME ${PROJECT_NAME}_vizkit.rb
            OPTIONAL)
    endif()
endfunction()

## Defines a new C++ test suite
#
# rock_testsuite(name
#     SOURCES source.cpp source1.cpp ...
#     [DEPS target1 target2 target3]
#     [DEPS_PKGCONFIG pkg1 pkg2 pkg3]
#     [DEPS_CMAKE pkg1 pkg2 pkg3]
#     [MOC qtsource1.hpp qtsource2.hpp])
#
# Creates a C++ test suite that is using the boost unit test framework
#
# The following arguments are mandatory:
#
# SOURCES: list of the C++ sources that should be built into that library
#
# The following optional arguments are available:
#
# DEPS: lists the other targets from this CMake project against which the
# library should be linked
# DEPS_PKGCONFIG: list of pkg-config packages that the library depends upon. The
# necessary link and compilation flags are added
# DEPS_CMAKE: list of packages which can be found with CMake's find_package,
# that the library depends upon. It is assumed that the Find*.cmake scripts
# follow the cmake accepted standard for variable naming
# MOC: if the library is Qt-based, a list of either source or header files.
# If headers are listed, these headers should be processed by moc, with the
# resulting implementation files are built into the library. If they are source
# files, they get added to the library and the corresponding header file is
# passed to moc.
function(rock_testsuite TARGET_NAME)
    if (TARGET_NAME STREQUAL "test")
        message(WARNING "test name cannot be 'test', renaming to '${PROJECT_NAME}-test'")
        set(TARGET_NAME "${PROJECT_NAME}-test")
    endif()
    add_definitions(-DBOOST_TEST_DYN_LINK)
    rock_executable(${TARGET_NAME} ${ARGN}
        NOINSTALL)
    target_link_libraries(${TARGET_NAME} ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
    add_test(NAME test-${TARGET_NAME}-cxx
        COMMAND ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})
endfunction()

macro(rock_libraries_for_pkgconfig VARNAME)
    foreach(__lib ${ARGN})
        string(STRIP __lib ${__lib})
        string(SUBSTRING ${__lib} 0 1 __lib_is_absolute)
        if (__lib_is_absolute STREQUAL "/")
            get_filename_component(__lib_path ${__lib} PATH)
            get_filename_component(__lib_name ${__lib} NAME_WE)
            string(REGEX REPLACE "^lib" "" __lib_name "${__lib_name}")
            set(${VARNAME} "${${VARNAME}} -L${__lib_path} -l${__lib_name}")
        else()
            set(${VARNAME} "${${VARNAME}} ${__lib}")
        endif()
    endforeach()
endmacro()

## List dependencies for the given target that are needed by the user of that
# target
#
# rock_add_public_dependencies(TARGET
#     [PLAIN] dep0 dep1 dep2
#     [CMAKE cmake_dep0 cmake_dep1 cmake_dep2]
#     [PKGCONFIG pkg_dep0 pkg_dep1 pkg_dep2])
#
# Declares a list of dependencies for the users of TARGET. It must be called
# before TARGET is defined
#
# These dependencies are going to be used automatically in the definition of
# TARGET, i.e. there is no need to repeat them in e.g. the rock_library call.
# This method also update the following variables:
#
#   ${TARGET_NAME}_PKGCONFIG_REQUIRES
#   ${TARGET_NAME}_PKGCONFIG_CFLAGS
#   ${TARGET_NAME}_PKGCONFIG_LIBS
#
# Which can be used in pkg-config files to automatically add the necessary
# information from these dependencies in the target's pkg-config file
#
# Unless you call this, all dependencies listed in the rock_* macro to create
# the target are public. You only need to call this to restrict the
# cross-project dependencies
macro(rock_add_public_dependencies TARGET_NAME)
    set(MODE PLAIN)
    foreach(__dep ${ARGN})
        if ("${__dep}" STREQUAL "CMAKE")
            set(MODE CMAKE)
        elseif ("${__dep}" STREQUAL "PLAIN")
            set(MODE PLAIN)
        elseif ("${__dep}" STREQUAL "PKGCONFIG")
            set(MODE PLAIN)
        else()
            list(APPEND ${TARGET_NAME}_PUBLIC_${MODE} "${__dep}")
        endif()
    endforeach()
endmacro()

