#!/usr/bin/env python3
"""Dependency-free deterministic Xcode project generator; checked-in project is ready to open."""
from pathlib import Path
import hashlib
import re
root = Path(__file__).resolve().parents[1]
def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s): return '"'+s.replace('"','\\"')+'"'
previous = root / 'sitescope.xcodeproj/project.pbxproj'
existing = previous.read_text() if previous.exists() else ''
team = re.search(r'DEVELOPMENT_TEAM = "?([A-Z0-9]+)"?;', existing)
bundle = re.search(r'PRODUCT_BUNDLE_IDENTIFIER = "?([^;" ]+\.sitescope)"?;', existing)
app_bundle = bundle.group(1) if bundle else 'com.example.sitescope'
objects = []
def obj(key, value): objects.append(f'{uid(key)} = {{ {value} }};'); return uid(key)
refs = []
products = []
targets = []
for name, folders, product_type in [('sitescope',['sitescope'],'application'),('sitescopeTests',['sitescopeTests','sitescopeAppTests'],'bundle.unit-test'),('sitescopeUITests',['sitescopeUITests'],'bundle.ui-testing')]:
    sources = []
    for folder in folders:
        for path in sorted((root/folder).rglob('*.swift')):
            rel = str(path.relative_to(root))
            ref = obj('file:'+rel,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT;')
            refs.append(ref)
            build = obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};')
            sources.append(build)
    extension = '.app' if name == 'sitescope' else '.xctest'
    product = obj('product:'+name,f'isa = PBXFileReference; explicitFileType = {q("wrapper.application" if name == "sitescope" else "wrapper.cfbundle")}; path = {q(name+extension)}; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    src = obj('sources:'+name,'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(sources)+'); runOnlyForDeploymentPostprocessing = 0;')
    framework = obj('frameworks:'+name,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resource = obj('resources:'+name,'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs=[]
    for config in ['Debug','Release']:
        settings = {'PRODUCT_NAME':'$(TARGET_NAME)','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','SWIFT_EMIT_LOC_STRINGS':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config == 'Debug' else '-O','ENABLE_TESTABILITY':'YES' if config == 'Debug' else 'NO'}
        if config == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) DEBUG'
        if name == 'sitescope':
            settings.update(INFOPLIST_FILE='sitescope/Resources/Info.plist',PRODUCT_BUNDLE_IDENTIFIER=app_bundle)
            if team: settings['DEVELOPMENT_TEAM'] = team.group(1)
        else:
            settings.update(GENERATE_INFOPLIST_FILE='YES',PRODUCT_BUNDLE_IDENTIFIER='com.example.'+name)
            if name == 'sitescopeTests': settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/sitescope.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/sitescope',BUNDLE_LOADER='$(TEST_HOST)')
            else: settings.update(TEST_TARGET_NAME='sitescope')
        base = f'baseConfigurationReference = {uid("configfile")};' if name == 'sitescope' else ''
        configs.append(obj(name+config,f'isa = XCBuildConfiguration; {base} name = {config}; buildSettings = {{ '+''.join(f'{k} = {q(v)};' for k,v in settings.items())+' };'))
    configlist = obj('configs:'+name,'isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    dependencies=[]
    if name != 'sitescope':
        proxy = obj('proxy:'+name,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:sitescope")}; remoteInfo = sitescope;')
        dependencies.append(obj('dependency:'+name,f'isa = PBXTargetDependency; target = {uid("target:sitescope")}; targetProxy = {proxy};'))
    targets.append(obj('target:'+name,f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({src},{framework},{resource}); buildRules = (); dependencies = ('+','.join(dependencies)+f'); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{product_type}";'))
refs.append(obj('configfile','isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = sitescope/Resources/Config.xcconfig; sourceTree = SOURCE_ROOT;'))
refs.append(obj('infofile','isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = sitescope/Resources/Info.plist; sourceTree = SOURCE_ROOT;'))
productgroup = obj('products','isa = PBXGroup; children = ('+','.join(products)+'); name = Products; sourceTree = "<group>";')
group = obj('main','isa = PBXGroup; children = ('+','.join(refs+[productgroup])+'); sourceTree = "<group>";')
configs=[]
for config in ['Debug','Release']:
    configs.append(obj('project:'+config,f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; }};'))
configlist=obj('projectconfigs','isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; }}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = {group}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = ('+','.join(targets)+');')
project=root/'sitescope.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid("project")}; }}\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def buildref(name):
    ext='.app' if name=='sitescope' else '.xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name+ext}" BlueprintName="{name}" ReferencedContainer="container:sitescope.xcodeproj"/>'
(schemes/'sitescope.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+buildref('sitescope')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'+''.join('<TestableReference skipped="NO">'+buildref(n)+'</TestableReference>' for n in ['sitescopeTests','sitescopeUITests'])+'</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+buildref('sitescope')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">'+buildref('sitescope')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
print('Generated sitescope.xcodeproj')
