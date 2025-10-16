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

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

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
  app/AppConfig.cpp
  app/wiring.cpp
  # services/HostClient.cpp
  # services/JavaProcess.cpp
  # services/OutboxStore.cpp
  # services/UpdaterService.cpp
  viewmodels/NavigationViewModel.cpp
  viewmodels/DashboardViewModel.cpp
  viewmodels/JobsViewModel.cpp
)

target_include_directories(packingelf PRIVATE app services viewmodels state)
target_link_libraries(packingelf PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2
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
    ui/components/Card.qml
    ui/components/MetricCard.qml
    ui/components/StatusLight.qml
    ui/components/NavButton.qml
    ui/components/Sidebar.qml
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


# (Optional) SCXML compile
# qt6_add_statecharts(packingelf state/Lifecycle.scxml)
