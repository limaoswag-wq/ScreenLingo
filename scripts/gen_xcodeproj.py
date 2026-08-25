#!/usr/bin/env python3
from pathlib import Path
import uuid

root = Path(__file__).resolve().parents[1]


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


ids = {k: uid() for k in [
    "project", "appTarget", "broadcastTarget", "appConfigList", "broadcastConfigList",
    "projectConfigList", "appDebug", "appRelease", "broadcastDebug", "broadcastRelease",
    "projectDebug", "projectRelease", "appSources", "appResources", "appFrameworks",
    "appEmbed", "broadcastSources", "broadcastResources", "broadcastFrameworks",
    "appGroup", "broadcastGroup", "sharedGroup", "productsGroup", "frameworksGroup",
    "appProduct", "broadcastProduct", "assets", "privacy", "appEnt", "broadcastEnt",
    "appPlist", "broadcastPlist",
]}

app_files = [
    ("ScreenLingoApp.swift", "App/ScreenLingoApp.swift"),
    ("HomeView.swift", "App/UI/HomeView.swift"),
    ("SettingsView.swift", "App/UI/SettingsView.swift"),
    ("RegionEditorView.swift", "App/UI/RegionEditorView.swift"),
    ("BroadcastPicker.swift", "App/UI/BroadcastPicker.swift"),
    ("Theme.swift", "App/UI/Theme.swift"),
    ("TranslationSessionController.swift", "App/Session/TranslationSessionController.swift"),
    ("OCREngine.swift", "App/OCR/OCREngine.swift"),
    ("Translator.swift", "App/Translation/Translator.swift"),
    ("PiPCaptionController.swift", "App/Overlay/PiPCaptionController.swift"),
    ("SilentAudio.swift", "App/Audio/SilentAudio.swift"),
]
shared_files = [
    ("AppConstants.swift", "Shared/AppConstants.swift"),
    ("Models.swift", "Shared/Models.swift"),
    ("AppSettings.swift", "Shared/AppSettings.swift"),
    ("AppGroupStore.swift", "Shared/AppGroupStore.swift"),
]
broadcast_files = [
    ("SampleHandler.swift", "Broadcast/SampleHandler.swift"),
]

file_ids = {}
build_ids_app = {}
build_ids_broadcast = {}
for name, path in app_files + shared_files + broadcast_files:
    file_ids[path] = uid()
for name, path in app_files + shared_files:
    build_ids_app[path] = uid()
for name, path in broadcast_files + shared_files:
    build_ids_broadcast[path] = uid()

assets_id = ids["assets"]
privacy_id = ids["privacy"]
assets_build = uid()
privacy_build = uid()
embed_build = uid()
dep = uid()
proxy = uid()
proj_id = uid()
ui_group = uid()
session_g = uid()
ocr_g = uid()
tr_g = uid()
ov_g = uid()
au_g = uid()

fw = {
    "ReplayKit": uid(),
    "AVKit": uid(),
    "AVFoundation": uid(),
    "Vision": uid(),
    "PhotosUI": uid(),
    "CoreMedia": uid(),
    "CoreImage": uid(),
    "CoreVideo": uid(),
    "ImageIO": uid(),
    "UniformTypeIdentifiers": uid(),
    "CryptoKit": uid(),
}
fw_build_app = {k: uid() for k in fw}
fw_build_broadcast = {
    k: uid() for k in [
        "ReplayKit", "CoreMedia", "CoreVideo", "CoreImage",
        "ImageIO", "UniformTypeIdentifiers",
    ]
}
quartz_file = uid()
quartz_build_b = uid()

P = []


def add(s: str = "") -> None:
    P.append(s)


add("// !$*UTF8*$!")
add("{")
add("\tarchiveVersion = 1;")
add("\tclasses = {")
add("\t};")
add("\tobjectVersion = 56;")
add("\tobjects = {")
add("")
add("/* Begin PBXBuildFile section */")
for name, path in app_files + shared_files:
    add(f"\t\t{build_ids_app[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
for name, path in broadcast_files + shared_files:
    add(f"\t\t{build_ids_broadcast[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
add(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_id} /* Assets.xcassets */; }};")
add(f"\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_id} /* PrivacyInfo.xcprivacy */; }};")
add(f"\t\t{embed_build} /* Broadcast.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {ids['broadcastProduct']} /* Broadcast.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
for k, fid in fw.items():
    add(f"\t\t{fw_build_app[k]} /* {k}.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fid} /* {k}.framework */; }};")
for k in fw_build_broadcast:
    add(f"\t\t{fw_build_broadcast[k]} /* {k}.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fw[k]} /* {k}.framework */; }};")
add(f"\t\t{quartz_build_b} /* QuartzCore.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {quartz_file} /* QuartzCore.framework */; }};")
add("/* End PBXBuildFile section */")
add("")
add("/* Begin PBXContainerItemProxy section */")
add(f"\t\t{proxy} /* PBXContainerItemProxy */ = {{")
add("\t\t\tisa = PBXContainerItemProxy;")
add(f"\t\t\tcontainerPortal = {proj_id} /* Project object */;")
add("\t\t\tproxyType = 1;")
add(f"\t\t\tremoteGlobalIDString = {ids['broadcastTarget']};")
add("\t\t\tremoteInfo = Broadcast;")
add("\t\t};")
add("/* End PBXContainerItemProxy section */")
add("")
add("/* Begin PBXCopyFilesBuildPhase section */")
add(f"\t\t{ids['appEmbed']} /* Embed App Extensions */ = {{")
add("\t\t\tisa = PBXCopyFilesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add('\t\t\tdstPath = "";')
add("\t\t\tdstSubfolderSpec = 13;")
add("\t\t\tfiles = (")
add(f"\t\t\t\t{embed_build} /* Broadcast.appex in Embed App Extensions */,")
add("\t\t\t);")
add('\t\t\tname = "Embed App Extensions";')
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXCopyFilesBuildPhase section */")
add("")
add("/* Begin PBXFileReference section */")
add(f"\t\t{ids['appProduct']} /* ScreenLingo.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ScreenLingo.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
add(f'\t\t{ids["broadcastProduct"]} /* Broadcast.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = Broadcast.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
add(f'\t\t{assets_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
add(f'\t\t{privacy_id} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; }};')
add(f'\t\t{ids["appEnt"]} /* ScreenLingo.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ScreenLingo.entitlements; sourceTree = "<group>"; }};')
add(f'\t\t{ids["appPlist"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
add(f'\t\t{ids["broadcastEnt"]} /* Broadcast.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Broadcast.entitlements; sourceTree = "<group>"; }};')
add(f'\t\t{ids["broadcastPlist"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
for name, path in app_files + shared_files + broadcast_files:
    add(f'\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};')
for k, fid in fw.items():
    add(f"\t\t{fid} /* {k}.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {k}.framework; path = System/Library/Frameworks/{k}.framework; sourceTree = SDKROOT; }};")
add(f"\t\t{quartz_file} /* QuartzCore.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = QuartzCore.framework; path = System/Library/Frameworks/QuartzCore.framework; sourceTree = SDKROOT; }};")
add("/* End PBXFileReference section */")
add("")
add("/* Begin PBXFrameworksBuildPhase section */")
add(f"\t\t{ids['appFrameworks']} /* Frameworks */ = {{")
add("\t\t\tisa = PBXFrameworksBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for k in fw:
    add(f"\t\t\t\t{fw_build_app[k]} /* {k}.framework in Frameworks */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add(f"\t\t{ids['broadcastFrameworks']} /* Frameworks */ = {{")
add("\t\t\tisa = PBXFrameworksBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for k in fw_build_broadcast:
    add(f"\t\t\t\t{fw_build_broadcast[k]} /* {k}.framework in Frameworks */,")
add(f"\t\t\t\t{quartz_build_b} /* QuartzCore.framework in Frameworks */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXFrameworksBuildPhase section */")
add("")
add("/* Begin PBXGroup section */")
add(f"\t\t{ids['project']} = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{ids['appGroup']} /* App */,")
add(f"\t\t\t\t{ids['sharedGroup']} /* Shared */,")
add(f"\t\t\t\t{ids['broadcastGroup']} /* Broadcast */,")
add(f"\t\t\t\t{ids['frameworksGroup']} /* Frameworks */,")
add(f"\t\t\t\t{ids['productsGroup']} /* Products */,")
add("\t\t\t);")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")
add(f"\t\t{ids['appGroup']} /* App */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{file_ids['App/ScreenLingoApp.swift']} /* ScreenLingoApp.swift */,")
add(f"\t\t\t\t{ui_group} /* UI */,")
add(f"\t\t\t\t{session_g} /* Session */,")
add(f"\t\t\t\t{ocr_g} /* OCR */,")
add(f"\t\t\t\t{tr_g} /* Translation */,")
add(f"\t\t\t\t{ov_g} /* Overlay */,")
add(f"\t\t\t\t{au_g} /* Audio */,")
add(f"\t\t\t\t{assets_id} /* Assets.xcassets */,")
add(f"\t\t\t\t{privacy_id} /* PrivacyInfo.xcprivacy */,")
add(f"\t\t\t\t{ids['appEnt']} /* ScreenLingo.entitlements */,")
add(f"\t\t\t\t{ids['appPlist']} /* Info.plist */,")
add("\t\t\t);")
add("\t\t\tpath = App;")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")


def subgroup(gid: str, title: str, files) -> None:
    add(f"\t\t{gid} /* {title} */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    for name, path in files:
        add(f"\t\t\t\t{file_ids[path]} /* {name} */,")
    add("\t\t\t);")
    add(f"\t\t\tpath = {title};")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")


subgroup(ui_group, "UI", [x for x in app_files if x[1].startswith("App/UI/")])
subgroup(session_g, "Session", [x for x in app_files if x[1].startswith("App/Session/")])
subgroup(ocr_g, "OCR", [x for x in app_files if x[1].startswith("App/OCR/")])
subgroup(tr_g, "Translation", [x for x in app_files if x[1].startswith("App/Translation/")])
subgroup(ov_g, "Overlay", [x for x in app_files if x[1].startswith("App/Overlay/")])
subgroup(au_g, "Audio", [x for x in app_files if x[1].startswith("App/Audio/")])

add(f"\t\t{ids['sharedGroup']} /* Shared */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for name, path in shared_files:
    add(f"\t\t\t\t{file_ids[path]} /* {name} */,")
add("\t\t\t);")
add("\t\t\tpath = Shared;")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")
add(f"\t\t{ids['broadcastGroup']} /* Broadcast */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{file_ids['Broadcast/SampleHandler.swift']} /* SampleHandler.swift */,")
add(f"\t\t\t\t{ids['broadcastEnt']} /* Broadcast.entitlements */,")
add(f"\t\t\t\t{ids['broadcastPlist']} /* Info.plist */,")
add("\t\t\t);")
add("\t\t\tpath = Broadcast;")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")
add(f"\t\t{ids['productsGroup']} /* Products */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{ids['appProduct']} /* ScreenLingo.app */,")
add(f"\t\t\t\t{ids['broadcastProduct']} /* Broadcast.appex */,")
add("\t\t\t);")
add("\t\t\tname = Products;")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")
add(f"\t\t{ids['frameworksGroup']} /* Frameworks */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for k, fid in fw.items():
    add(f"\t\t\t\t{fid} /* {k}.framework */,")
add(f"\t\t\t\t{quartz_file} /* QuartzCore.framework */,")
add("\t\t\t);")
add("\t\t\tname = Frameworks;")
add('\t\t\tsourceTree = "<group>";')
add("\t\t};")
add("/* End PBXGroup section */")
add("")
add("/* Begin PBXNativeTarget section */")
add(f"\t\t{ids['appTarget']} /* ScreenLingo */ = {{")
add("\t\t\tisa = PBXNativeTarget;")
add(f'\t\t\tbuildConfigurationList = {ids["appConfigList"]} /* Build configuration list for PBXNativeTarget "ScreenLingo" */;')
add("\t\t\tbuildPhases = (")
add(f"\t\t\t\t{ids['appSources']} /* Sources */,")
add(f"\t\t\t\t{ids['appFrameworks']} /* Frameworks */,")
add(f"\t\t\t\t{ids['appResources']} /* Resources */,")
add(f"\t\t\t\t{ids['appEmbed']} /* Embed App Extensions */,")
add("\t\t\t);")
add("\t\t\tbuildRules = (")
add("\t\t\t);")
add("\t\t\tdependencies = (")
add(f"\t\t\t\t{dep} /* PBXTargetDependency */,")
add("\t\t\t);")
add("\t\t\tname = ScreenLingo;")
add("\t\t\tproductName = ScreenLingo;")
add(f"\t\t\tproductReference = {ids['appProduct']} /* ScreenLingo.app */;")
add('\t\t\tproductType = "com.apple.product-type.application";')
add("\t\t};")
add(f"\t\t{ids['broadcastTarget']} /* Broadcast */ = {{")
add("\t\t\tisa = PBXNativeTarget;")
add(f'\t\t\tbuildConfigurationList = {ids["broadcastConfigList"]} /* Build configuration list for PBXNativeTarget "Broadcast" */;')
add("\t\t\tbuildPhases = (")
add(f"\t\t\t\t{ids['broadcastSources']} /* Sources */,")
add(f"\t\t\t\t{ids['broadcastFrameworks']} /* Frameworks */,")
add(f"\t\t\t\t{ids['broadcastResources']} /* Resources */,")
add("\t\t\t);")
add("\t\t\tbuildRules = (")
add("\t\t\t);")
add("\t\t\tdependencies = (")
add("\t\t\t);")
add("\t\t\tname = Broadcast;")
add("\t\t\tproductName = Broadcast;")
add(f"\t\t\tproductReference = {ids['broadcastProduct']} /* Broadcast.appex */;")
add('\t\t\tproductType = "com.apple.product-type.app-extension";')
add("\t\t};")
add("/* End PBXNativeTarget section */")
add("")
add("/* Begin PBXProject section */")
add(f"\t\t{proj_id} /* Project object */ = {{")
add("\t\t\tisa = PBXProject;")
add("\t\t\tattributes = {")
add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
add("\t\t\t\tLastSwiftUpdateCheck = 1600;")
add("\t\t\t\tLastUpgradeCheck = 1600;")
add("\t\t\t\tTargetAttributes = {")
add(f"\t\t\t\t\t{ids['appTarget']} = {{")
add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
add("\t\t\t\t\t};")
add(f"\t\t\t\t\t{ids['broadcastTarget']} = {{")
add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
add("\t\t\t\t\t};")
add("\t\t\t\t};")
add("\t\t\t};")
add(f'\t\t\tbuildConfigurationList = {ids["projectConfigList"]} /* Build configuration list for PBXProject "ScreenLingo" */;')
add('\t\t\tcompatibilityVersion = "Xcode 14.0";')
add('\t\t\tdevelopmentRegion = "zh-Hans";')
add("\t\t\thasScannedForEncodings = 0;")
add("\t\t\tknownRegions = (")
add("\t\t\t\ten,")
add("\t\t\t\tBase,")
add('\t\t\t\t"zh-Hans",')
add("\t\t\t);")
add(f"\t\t\tmainGroup = {ids['project']};")
add(f"\t\t\tproductRefGroup = {ids['productsGroup']} /* Products */;")
add('\t\t\tprojectDirPath = "";')
add('\t\t\tprojectRoot = "";')
add("\t\t\ttargets = (")
add(f"\t\t\t\t{ids['appTarget']} /* ScreenLingo */,")
add(f"\t\t\t\t{ids['broadcastTarget']} /* Broadcast */,")
add("\t\t\t);")
add("\t\t};")
add("/* End PBXProject section */")
add("")
add("/* Begin PBXResourcesBuildPhase section */")
add(f"\t\t{ids['appResources']} /* Resources */ = {{")
add("\t\t\tisa = PBXResourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
add(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
add(f"\t\t\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add(f"\t\t{ids['broadcastResources']} /* Resources */ = {{")
add("\t\t\tisa = PBXResourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXResourcesBuildPhase section */")
add("")
add("/* Begin PBXSourcesBuildPhase section */")
add(f"\t\t{ids['appSources']} /* Sources */ = {{")
add("\t\t\tisa = PBXSourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for name, path in app_files + shared_files:
    add(f"\t\t\t\t{build_ids_app[path]} /* {name} in Sources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add(f"\t\t{ids['broadcastSources']} /* Sources */ = {{")
add("\t\t\tisa = PBXSourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for name, path in broadcast_files + shared_files:
    add(f"\t\t\t\t{build_ids_broadcast[path]} /* {name} in Sources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXSourcesBuildPhase section */")
add("")
add("/* Begin PBXTargetDependency section */")
add(f"\t\t{dep} /* PBXTargetDependency */ = {{")
add("\t\t\tisa = PBXTargetDependency;")
add(f"\t\t\ttarget = {ids['broadcastTarget']} /* Broadcast */;")
add(f"\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;")
add("\t\t};")
add("/* End PBXTargetDependency section */")
add("")


def xcconfig(cid: str, name: str, extra) -> None:
    add(f"\t\t{cid} /* {name} */ = {{")
    add("\t\t\tisa = XCBuildConfiguration;")
    add("\t\t\tbuildSettings = {")
    for k, v in extra:
        add(f"\t\t\t\t{k} = {v};")
    add("\t\t\t};")
    add(f"\t\t\tname = {name};")
    add("\t\t};")


add("/* Begin XCBuildConfiguration section */")
common_proj = [
    ("ALWAYS_SEARCH_USER_PATHS", "NO"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("COPY_PHASE_STRIP", "NO"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("GCC_NO_COMMON_BLOCKS", "YES"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "16.0"),
    ("SDKROOT", "iphoneos"),
    ("SWIFT_VERSION", "5.0"),
]
xcconfig(ids["projectDebug"], "Debug", common_proj + [
    ("DEBUG_INFORMATION_FORMAT", "dwarf"),
    ("ENABLE_TESTABILITY", "YES"),
    ("GCC_DYNAMIC_NO_PIC", "NO"),
    ("GCC_OPTIMIZATION_LEVEL", "0"),
    ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
    ("ONLY_ACTIVE_ARCH", "YES"),
    ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
    ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
])
xcconfig(ids["projectRelease"], "Release", common_proj + [
    ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
    ("ENABLE_NS_ASSERTIONS", "NO"),
    ("MTL_ENABLE_DEBUG_INFO", "NO"),
    ("SWIFT_COMPILATION_MODE", "wholemodule"),
    ("SWIFT_OPTIMIZATION_LEVEL", '"-O"'),
    ("VALIDATE_PRODUCT", "YES"),
])
app_settings = [
    ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
    ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
    ("CODE_SIGN_ENTITLEMENTS", "App/ScreenLingo.entitlements"),
    ("CODE_SIGNING_ALLOWED", "NO"),
    ("CODE_SIGNING_REQUIRED", "NO"),
    ("CODE_SIGN_IDENTITY", '""'),
    ("CODE_SIGN_STYLE", "Manual"),
    ("CURRENT_PROJECT_VERSION", "8"),
    ("DEVELOPMENT_TEAM", '""'),
    ("GENERATE_INFOPLIST_FILE", "NO"),
    ("INFOPLIST_FILE", "App/Info.plist"),
    ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks"'),
    ("MARKETING_VERSION", "1.0.6"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "dev.screenlingo.app"),
    ("PRODUCT_NAME", "ScreenLingo"),
    ("SUPPORTS_MACCATALYST", "NO"),
    ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ("TARGETED_DEVICE_FAMILY", '"1,2"'),
]
xcconfig(ids["appDebug"], "Debug", app_settings)
xcconfig(ids["appRelease"], "Release", app_settings)
b_settings = [
    ("CODE_SIGN_ENTITLEMENTS", "Broadcast/Broadcast.entitlements"),
    ("CODE_SIGNING_ALLOWED", "NO"),
    ("CODE_SIGNING_REQUIRED", "NO"),
    ("CODE_SIGN_IDENTITY", '""'),
    ("CODE_SIGN_STYLE", "Manual"),
    ("CURRENT_PROJECT_VERSION", "8"),
    ("DEVELOPMENT_TEAM", '""'),
    ("GENERATE_INFOPLIST_FILE", "NO"),
    ("INFOPLIST_FILE", "Broadcast/Info.plist"),
    ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"'),
    ("MARKETING_VERSION", "1.0.6"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "dev.screenlingo.app.broadcast"),
    ("PRODUCT_NAME", "Broadcast"),
    ("SKIP_INSTALL", "YES"),
    ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ("TARGETED_DEVICE_FAMILY", '"1,2"'),
]
xcconfig(ids["broadcastDebug"], "Debug", b_settings)
xcconfig(ids["broadcastRelease"], "Release", b_settings)
add("/* End XCBuildConfiguration section */")
add("")
add("/* Begin XCConfigurationList section */")


def clist(cid: str, title: str, debug: str, release: str) -> None:
    add(f"\t\t{cid} /* Build configuration list for {title} */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{debug} /* Debug */,")
    add(f"\t\t\t\t{release} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")


clist(ids["projectConfigList"], 'PBXProject "ScreenLingo"', ids["projectDebug"], ids["projectRelease"])
clist(ids["appConfigList"], 'PBXNativeTarget "ScreenLingo"', ids["appDebug"], ids["appRelease"])
clist(ids["broadcastConfigList"], 'PBXNativeTarget "Broadcast"', ids["broadcastDebug"], ids["broadcastRelease"])
add("/* End XCConfigurationList section */")
add("\t};")
add(f"\trootObject = {proj_id} /* Project object */;")
add("}")

out = root / "ScreenLingo.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(P) + "\n", encoding="utf-8")
print("wrote", out, "lines", len(P))
