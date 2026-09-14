; CPRedux Desktop - NSIS Installer Script
; Windows Setup Installer (.exe) per CPRedux Desktop Suite

Unicode True
!include "MUI2.nsh"
!include "FileFunc.nsh"

!define PRODUCT_NAME "CPRedux Desktop"
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.2.4"
!endif
!define PRODUCT_PUBLISHER "CPRedux Team"
!define PRODUCT_WEB_SITE "https://gitlab.com/Tia004/cpredux"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\CPRedux"
!define PRODUCT_DIR_REGKEY "Software\CPRedux"

!ifndef BUILD_DIR
  !define BUILD_DIR "..\..\build\windows\x64\runner\Release"
!endif
!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "cpredux-v0.2.4-setup.exe"
!endif
!ifndef APP_ICON
  !define APP_ICON "..\runner\resources\app_icon.ico"
!endif
!ifndef LOGO_IMAGE
  !define LOGO_IMAGE "..\..\assets\branding\CPReduxLogo.png"
!endif

Name "${PRODUCT_NAME}"
Caption "${PRODUCT_NAME} v${PRODUCT_VERSION} Setup"
OutFile "${OUTPUT_EXE}"
InstallDir "$LOCALAPPDATA\Programs\CPRedux Desktop"
InstallDirRegKey HKCU "${PRODUCT_DIR_REGKEY}" "Install_Dir"
RequestExecutionLevel user

!define MUI_ICON "${APP_ICON}"
!define MUI_UNICON "${APP_ICON}"
!define MUI_ABORTWARNING

; Informazioni Versione PE
VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "LegalCopyright" "GPL-3.0"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} Setup"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}.0"

; Pagine di Installazione (Modern UI 2)
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\cpredux.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Avvia CPRedux Desktop"
!insertmacro MUI_PAGE_FINISH

; Pagine di Disinstallazione
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Lingue
!insertmacro MUI_LANGUAGE "Italian"
!insertmacro MUI_LANGUAGE "English"

Section "CPRedux Desktop" SecCore
  SetOutPath "$INSTDIR"
  
  ; File Principali dell'applicazione Flutter (cpredux.exe, flutter_windows.dll, cartella data, ecc.)
  File /r "${BUILD_DIR}\*.*"
  File "${APP_ICON}"
  
  SetOutPath "$INSTDIR\assets"
  File "${LOGO_IMAGE}"
  
  SetOutPath "$INSTDIR"

  ; Creazione Uninstaller Ufficiale
  WriteUninstaller "$INSTDIR\Uninstall CPRedux.exe"

  ; Collegamenti Menu Start e Desktop
  CreateDirectory "$SMPROGRAMS\CPRedux Desktop"
  CreateShortcut "$SMPROGRAMS\CPRedux Desktop\CPRedux Desktop.lnk" "$INSTDIR\cpredux.exe" "" "$INSTDIR\app_icon.ico" 0
  CreateShortcut "$SMPROGRAMS\CPRedux Desktop\Disinstalla CPRedux.lnk" "$INSTDIR\Uninstall CPRedux.exe" "" "$INSTDIR\app_icon.ico" 0
  CreateShortcut "$DESKTOP\CPRedux Desktop.lnk" "$INSTDIR\cpredux.exe" "" "$INSTDIR\app_icon.ico" 0

  ; Registrazione Registro Windows (App & Funzionalità / Installazione Applicazioni)
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "Install_Dir" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\app_icon.ico"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "HelpLink" "${PRODUCT_WEB_SITE}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall CPRedux.exe"'
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall CPRedux.exe" /S'
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoRepair" 1

  ; Associazione file .cpredux con icona ufficiale e apertura con doppio click
  WriteRegStr HKCU "Software\Classes\.cpredux" "" "CPRedux.Sheet"
  WriteRegStr HKCU "Software\Classes\CPRedux.Sheet" "" "Documento Scheda CPRedux"
  WriteRegStr HKCU "Software\Classes\CPRedux.Sheet\DefaultIcon" "" "$INSTDIR\app_icon.ico,0"
  WriteRegStr HKCU "Software\Classes\CPRedux.Sheet\shell\open\command" "" '"$INSTDIR\cpredux.exe" "%1"'
SectionEnd

Section "Uninstall"
  ; Rimozione Collegamenti
  Delete "$DESKTOP\CPRedux Desktop.lnk"
  Delete "$SMPROGRAMS\CPRedux Desktop\CPRedux Desktop.lnk"
  Delete "$SMPROGRAMS\CPRedux Desktop\Disinstalla CPRedux.lnk"
  RMDir "$SMPROGRAMS\CPRedux Desktop"

  ; Rimozione File e Cartelle
  Delete "$INSTDIR\cpredux.exe"
  Delete "$INSTDIR\flutter_windows.dll"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\app_icon.ico"
  RMDir /r "$INSTDIR\data"
  RMDir /r "$INSTDIR\assets"
  Delete "$INSTDIR\Uninstall CPRedux.exe"
  RMDir "$INSTDIR"

  ; Rimozione Associazione File
  DeleteRegKey HKCU "Software\Classes\.cpredux"
  DeleteRegKey HKCU "Software\Classes\CPRedux.Sheet"

  ; Rimozione Chiavi di Registro
  DeleteRegKey HKCU "${PRODUCT_UNINST_KEY}"
  DeleteRegKey HKCU "${PRODUCT_DIR_REGKEY}"
SectionEnd
