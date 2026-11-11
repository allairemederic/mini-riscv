#!/usr/bin/env tcsh
#-----------------------------------------------------------------------------
# Project  Tutoriels - Conception de circuits intégrés numériques
#-----------------------------------------------------------------------------
# File     setup.csh
# Authors  Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      GRM - Polytechnique Montréal
# Date       : <2020-07-23>
# Date       : <2024-04-03> modification par Rejean Lepage (tuto numerique)
# Date       : <2025-09-03> modification par Rejean Lepage (tuto numerique)
# Date       : <2026-09-14> modernisation outils CMC + kit GPDK045 v6 (Alexandre Baux)
#-----------------------------------------------------------------------------
# Brief    Script de configuration de l'environnement
#          - Environnement CMC
#          - Hiérarchie du projet
#          - kit Cadence GPDK045 (gsclib045 v4.8)
#          - Outils Cadence (DDI 25.1) et Siemens Questa
#-----------------------------------------------------------------------------
# Source depuis la racine du projet:
#   cd ~/Labs/tutoriel_numerique
#   source setup.csh
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# CONFIGURATION
#-----------------------------------------------------------------------------
setenv CMC_CONFIG   "/CMC/scripts/cmc.2026.02.csh"
setenv PROJECT_HOME `pwd`

if ( ! -f ${PROJECT_HOME}/setup.csh ) then
    echo "ERROR: setup.csh doit être lancé depuis la racine du projet"
    exit 1
endif

if ( ! -f ${CMC_CONFIG} ) then
    echo "ERROR: L'environnement n'est pas configuré pour les outils de CMC"
    echo "       Fichier manquant: ${CMC_CONFIG}"
    exit 1
endif

source ${CMC_CONFIG}

# Les installs Cadence de ce laboratoire sont suffixées _lnx86, même sur RHEL8.
if ( $?CMC_CDS_ARCH ) then
    if ( "${CMC_CDS_ARCH}" != "lnx86" ) then
        setenv CMC_CDS_ARCH lnx86
    endif
else
    setenv CMC_CDS_ARCH lnx86
endif

setenv WORK_DIR "${PROJECT_HOME}/work"
if ( ! -d "${WORK_DIR}" ) mkdir -p "${WORK_DIR}"

setenv CDS_AUTO_64BIT ALL
setenv CDS_LOAD_ENV   addCWD
setenv DRCTEMPDIR     "${WORK_DIR}/cadence-tmp"
if ( ! -d "${DRCTEMPDIR}" ) mkdir -p "${DRCTEMPDIR}"

#-----------------------------------------------------------------------------
# HIERARCHIE DU PROJET
#-----------------------------------------------------------------------------
setenv SRC_DIR          ${PROJECT_HOME}/sources
setenv CONST_DIR        ${PROJECT_HOME}/constraints
setenv SCRIPTS_DIR      ${PROJECT_HOME}/scripts
setenv SIM_DIR          ${PROJECT_HOME}/simulation
setenv SIM_BEH_DIR      ${SIM_DIR}/beh
setenv SIM_SYN_DIR      ${SIM_DIR}/syn
setenv SIM_PNR_DIR      ${SIM_DIR}/pnr
setenv IMP_DIR          ${PROJECT_HOME}/implementation
setenv SYN_DIR          ${IMP_DIR}/syn
setenv SYN_NET_DIR      ${SYN_DIR}/base_netlist
setenv SYN_REP_DIR      ${SYN_DIR}/base_reports
setenv SYN_LOG_DIR      ${SYN_DIR}/base_logs
setenv SYN_CG_NET_DIR   ${SYN_DIR}/cg_netlist
setenv SYN_CG_REP_DIR   ${SYN_DIR}/cg_reports
setenv SYN_CG_LOG_DIR   ${SYN_DIR}/cg_logs
setenv SYN_DFT_NET_DIR  ${SYN_DIR}/dft_netlist
setenv SYN_DFT_REP_DIR  ${SYN_DIR}/dft_reports
setenv SYN_DFT_LOG_DIR  ${SYN_DIR}/dft_logs
setenv ATPG_DIR         ${IMP_DIR}/atpg
setenv PNR_DIR          ${IMP_DIR}/pnr
setenv PNR_NET_DIR      ${PNR_DIR}/base_netlist
setenv PNR_REP_DIR      ${PNR_DIR}/base_reports
setenv PNR_LOG_DIR      ${PNR_DIR}/base_logs
setenv PNR_SAVE_DIR     ${PNR_DIR}/save
setenv PNR_CG_NET_DIR   ${PNR_DIR}/cg_netlist
setenv PNR_CG_REP_DIR   ${PNR_DIR}/cg_reports
setenv PNR_CG_LOG_DIR   ${PNR_DIR}/cg_logs
setenv PNR_DFT_NET_DIR  ${PNR_DIR}/dft_netlist
setenv PNR_DFT_REP_DIR  ${PNR_DIR}/dft_reports
setenv PNR_DFT_LOG_DIR  ${PNR_DIR}/dft_logs

foreach _dir ( \
    "${WORK_DIR}" "${DRCTEMPDIR}" \
    "${SYN_NET_DIR}" "${SYN_REP_DIR}" "${SYN_LOG_DIR}" \
    "${SYN_CG_NET_DIR}" "${SYN_CG_REP_DIR}" "${SYN_CG_LOG_DIR}" \
    "${SYN_DFT_NET_DIR}" "${SYN_DFT_REP_DIR}" "${SYN_DFT_LOG_DIR}" \
    "${ATPG_DIR}" \
    "${PNR_NET_DIR}" "${PNR_REP_DIR}" "${PNR_LOG_DIR}" "${PNR_SAVE_DIR}" \
    "${PNR_CG_NET_DIR}" "${PNR_CG_REP_DIR}" "${PNR_CG_LOG_DIR}" \
    "${PNR_DFT_NET_DIR}" "${PNR_DFT_REP_DIR}" "${PNR_DFT_LOG_DIR}" \
    "${SIM_BEH_DIR}" "${SIM_SYN_DIR}" "${SIM_PNR_DIR}" )
    if ( ! -d "${_dir}" ) mkdir -p "${_dir}"
end
unset _dir

#-----------------------------------------------------------------------------
# CONFIGURATION DU KIT GPDK045
#-----------------------------------------------------------------------------
setenv KIT_HOME    ${CMC_HOME}/kits/cadence/GPDK045
setenv KIT_SCLIB   ${KIT_HOME}/gsclib045_all_v4.8/gsclib045
setenv KIT_IOLIB   ${KIT_HOME}/giolib045_v3.3
setenv KIT_GPDK    ${KIT_HOME}/gpdk045_v_6_0
setenv KIT_SIMLIB  ${KIT_HOME}/simlib
setenv GPDK_DIR    ${KIT_GPDK}

# Front-End
setenv FE_VER_LIB  ${KIT_SCLIB}/verilog
setenv FE_VHD_LIB  ${KIT_SCLIB}/vhdl
setenv FE_TIM_LIB  ${KIT_SCLIB}/timing

# Back-End
setenv BE_LEF_LIB   ${KIT_SCLIB}/lef
setenv BE_CDB_LIB   ${KIT_SCLIB}/celtic
setenv BE_OA_LIB    ${KIT_SCLIB}/oa22/gsclib045
setenv BE_QRC_LIB   ${KIT_SCLIB}/qrc/qx
setenv BE_GDS_LIB   ${KIT_SCLIB}/gds
setenv BE_SPICE_LIB ${KIT_SCLIB}/spectre/gsclib045
setenv BE_CDL_LIB   ${KIT_SCLIB}/cdl
setenv BE_GDS_MAP   ${GPDK_DIR}/soce/streamOut.map
setenv PVS_RULE_DIR ${GPDK_DIR}/pvs

# I/O
setenv IO_VHDL_LIB ${KIT_IOLIB}/vhdl
setenv IO_VER_LIB  ${KIT_IOLIB}/vlog
setenv IO_LEF_LIB  ${KIT_IOLIB}/lef
setenv IO_OA_LIB   ${KIT_IOLIB}/oa22/giolib045

if ( ! -d "${KIT_HOME}" ) then
    echo "ERROR: Kit GPDK045 introuvable: ${KIT_HOME}"
    exit 1
endif

#-----------------------------------------------------------------------------
# CONFIGURATION DES OUTILS
#-----------------------------------------------------------------------------

# QUESTA / MODELSIM (2025.2 a un script CMC, mais n'est pas installé ici)
source ${CMC_HOME}/scripts/siemens.questasim.2024.1.csh
alias vsim "vsim -64"
if ( $?CMC_MNT_QSIM_HOME ) then
    alias vsim_help "xdg-open ${CMC_MNT_QSIM_HOME}/docs/index.html >& /dev/null &"
endif

# XCELIUM (simulation ATPG / Verilog)
if ( ! -d /CMC/tools/cadence/XCELIUMMAIN23.09.006_${CMC_CDS_ARCH} && \
     -d /CMC/tools/cadence/XCELIUMMAIN23.09.006_lnx86 ) then
    setenv CMC_CDS_ARCH lnx86
endif
source /CMC/scripts/cadence.xceliummain23.09.006.csh
alias xcelium_help "${CMC_CDS_XCELIUMMAIN_HOME}/bin/cdnshelp"

# DDI 25.10 : Genus 25.1 + Innovus 25.1
# Le script CMC ajoute encore GENUS231/INNOVUS231 au PATH; on corrige ensuite.
if ( ! -d /CMC/tools/cadence/DDI25.10.000_${CMC_CDS_ARCH} && \
     -d /CMC/tools/cadence/DDI25.10.000_lnx86 ) then
    setenv CMC_CDS_ARCH lnx86
endif
source /CMC/scripts/cadence.ddi25.10.000.csh
setenv CMC_CDS_GENUS_HOME   "${CMC_CDS_DDI_HOME}/GENUS251"
setenv CMC_CDS_INNOVUS_HOME "${CMC_CDS_DDI_HOME}/INNOVUS251"
setenv PATH "${CMC_CDS_GENUS_HOME}/bin:${CMC_CDS_GENUS_HOME}/tools.lnx86/bin:${CMC_CDS_INNOVUS_HOME}/bin:${CMC_CDS_INNOVUS_HOME}/tools.lnx86/bin:${PATH}"
alias genus "genus -overwrite"
alias genus_help "${CMC_CDS_GENUS_HOME}/bin/cdnshelp"
alias innovus "innovus -overwrite -no_logv"
alias innovus_help "${CMC_CDS_INNOVUS_HOME}/bin/cdnshelp"

# MODUS (ATPG) — scripts CMC présents, binaire souvent absent de ce poste
setenv CMC_CDS_MODUS_HOME ""
foreach _modus ( MODUS25.10.000 MODUS23.12.000 MODUS23.10.000 MODUS22.11.000 MODUS21.11.000 MODUS20.12.000 MODUS19.12.000 )
    if ( -d /CMC/tools/cadence/${_modus}_${CMC_CDS_ARCH} ) then
        setenv CMC_CDS_MODUS_HOME /CMC/tools/cadence/${_modus}_${CMC_CDS_ARCH}
        break
    else if ( -d /CMC/tools/cadence/${_modus}_lnx86 ) then
        setenv CMC_CDS_MODUS_HOME /CMC/tools/cadence/${_modus}_lnx86
        break
    endif
end
if ( "${CMC_CDS_MODUS_HOME}" != "" ) then
    setenv PATH "${CMC_CDS_MODUS_HOME}/bin:${CMC_CDS_MODUS_HOME}/tools.lnx86/bin:${PATH}"
    alias modus "modus -overwrite"
    alias modus_help "${CMC_CDS_MODUS_HOME}/bin/cdnshelp"
else
    echo "WARNING: Modus n'est pas installé sous /CMC/tools/cadence (nécessaire pour l'ATPG du tutoriel DFT)."
endif
unset _modus

# VOLTUS / TEMPUS (SSV 25.10 n'est pas installé; 23.12 l'est)
source /CMC/scripts/cadence.ssv23.12.000.csh
alias voltus "voltus -overwrite -no_logv"
alias tempus "tempus -overwrite -no_logv"
alias voltus_help "${CMC_CDS_SSV_HOME}/bin/cdnshelp"
alias tempus_help "${CMC_CDS_SSV_HOME}/bin/cdnshelp"

# QUANTUS (extraction RC; remplace EXT/QRC pour les nouvelles versions)
source /CMC/scripts/cadence.quantus25.10.000.csh

# PVS (même version que le tutoriel analogique)
source /CMC/scripts/cadence.pvs25.10.000.csh
alias pvs_help "${CMC_CDS_PVS_HOME}/bin/cdnshelp"

# CONFORMAL (LEC)
if ( -d /CMC/tools/cadence/CONFRML23.10.200_${CMC_CDS_ARCH} || \
     -d /CMC/tools/cadence/CONFRML23.10.200_lnx86 ) then
    source /CMC/scripts/cadence.confrml23.10.200.csh
endif

echo "Environnement pret:"
echo "  Kit     : ${KIT_HOME}"
echo "  Questa  : ${CMC_MNT_QSIM_HOME}"
echo "  Xcelium : ${CMC_CDS_XCELIUMMAIN_HOME}"
echo "  Genus   : ${CMC_CDS_GENUS_HOME}"
echo "  Innovus : ${CMC_CDS_INNOVUS_HOME}"
if ( "${CMC_CDS_MODUS_HOME}" != "" ) then
    echo "  Modus   : ${CMC_CDS_MODUS_HOME}"
else
    echo "  Modus   : (non installe)"
endif
echo "  SSV     : ${CMC_CDS_SSV_HOME}"
echo "  Quantus : ${CMC_CDS_QUANTUS_HOME}"
echo "  PVS     : ${CMC_CDS_PVS_HOME}"
