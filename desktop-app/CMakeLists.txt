#  ─────────────────────────────────────────────────────────────
#  CMake configuration for PackingElf desktop application
#  ─────────────────────────────────────────────────────────────
cmake_minimum_required(VERSION 3.25)
project(PackingElf VERSION 1.0.0 LANGUAGES CXX)

# Allow C++ standard to be overridden via -DPACKINGELF_CXX_STANDARD=17
if(NOT DEFINED PACKINGELF_CXX_STANDARD)
  set(PACKINGELF_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_STANDARD ${PACKINGELF_CXX_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Fix MSVC C++ standard detection for Qt6
if(MSVC)
  add_compile_options(/Zc:__cplusplus)
endif()

# Qt automation
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Enable QML language server support for better IDE integration
set(QT_QML_GENERATE_QMLLS_INI ON CACHE BOOL "Generate qmlls.ini for QML language server" FORCE)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Sql)

#  ─────────────────────────────────────────────────────────────
#  Silence Qt policy warnings with sensible defaults
#  ─────────────────────────────────────────────────────────────
qt_policy(SET QTP0001 NEW)  # use default :/qt/qml/ prefix for the module
qt_policy(SET QTP0004 OLD)  # allow extra subdirs without per-dir qmldir files

#  ─────────────────────────────────────────────────────────────
#  All source files for the PackingElf application
#  ─────────────────────────────────────────────────────────────
add_executable(packingelf
  app/main.cpp
  app/wiring.cpp
  data/Database.cpp
  data/OrdersRepository.cpp
  viewmodels/OrdersViewModel.cpp
  viewmodels/DashboardViewModel.cpp
)

target_include_directories(packingelf PRIVATE app data services viewmodels state)
target_link_libraries(packingelf PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Sql
)

#  ─────────────────────────────────────────────────────────────
#  include all singleton QML files in first line
#  ─────────────────────────────────────────────────────────────
set(qml_singletons 
  ui/Theme.qml 
  ui/Constants.qml 
  ui/NavStore.qml
)
set_source_files_properties(${qml_singletons} PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

#  ─────────────────────────────────────────────────────────────
#  add QML module
#  ─────────────────────────────────────────────────────────────
qt_add_qml_module(packingelf
  URI PackingElf
  VERSION 1.0
  OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/PackingElf
  RESOURCE_PREFIX /qt/qml
  
  # QML files
  QML_FILES
    ui/App.qml
    ui/views/MainScreen.qml
    ui/views/HomePage.qml
    ui/views/SettingPage.qml
    ui/views/PrintingPage.qml
    ui/views/HistoryPage.qml
    ui/components/Card.qml
    ui/components/MetricCard.qml
    ui/components/StatusLight.qml
    ui/components/NavButton.qml
    ui/components/ContentPage.qml
    ui/components/CustomDropdown.qml
    ui/components/CustomCheckBox.qml
    ui/components/CustomEntry.qml
    ui/components/CustomButton.qml
    ui/components/CustomTable.qml
    ui/components/CustomSpinBox.qml
    ui/components/CustomProgressBar.qml
    ui/components/CustomBusyIndicator.qml

    # Singletons
    ui/Constants.qml
    ui/Theme.qml
    ui/NavStore.qml

  # Assets (commented out until you copy image files from prototype)
  RESOURCES
    ui/assets/images/home.svg
    ui/assets/images/printing.svg
    ui/assets/images/settings.svg
    ui/assets/images/history.svg
    ui/assets/images/profile.svg
    ui/assets/images/user.svg
    ui/assets/images/record.svg
    ui/assets/images/towa_4.png
    ui/assets/images/meridian.svg
    ui/assets/images/total_orders.svg
    ui/assets/images/shipped.svg
    ui/assets/images/pending.svg
)

# Post-build: deploy Qt dependencies (DLLs, QML modules, translations)
# This runs windeployqt automatically after every build
find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${Qt6_DIR}/../../../bin")
if(WINDEPLOYQT_EXECUTABLE)
  # For Debug builds: deploy everything (easier development)
  # For Release builds: minimal deployment (smaller distribution size)
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(DEPLOY_ARGS
      --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/ui"
      "$<TARGET_FILE:packingelf>"
    )
  else()
    set(DEPLOY_ARGS
      --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/ui"
      --no-translations          # Skip 30+ translation files
      --no-system-d3d-compiler   # Skip D3D compiler (usually not needed)
      --no-opengl-sw             # Skip software OpenGL renderer
      "$<TARGET_FILE:packingelf>"
    )
  endif()
  
  add_custom_command(TARGET packingelf POST_BUILD
    COMMAND "${WINDEPLOYQT_EXECUTABLE}" ${DEPLOY_ARGS}
    COMMENT "Running windeployqt (${CMAKE_BUILD_TYPE} mode)"
  )
else()
  message(WARNING "windeployqt not found. You'll need to manually deploy Qt DLLs.")
endif()

# (Optional) SCXML compile
# qt6_add_statecharts(packingelf state/Lifecycle.scxml)
