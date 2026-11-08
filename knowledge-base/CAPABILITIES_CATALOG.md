# Ola S1 Pro — capability & parameter catalog

Auto-generated from the diagnostic app's ODX (`notes/apk_x/res/raw/odx.json`),
firmware 5.0.0. This lists every command the diagnostic protocol exposes:
self-tests, actuator/component tests, and **writable configuration parameters**.

> SAFETY: writable params below are the ECU's raw calibration values. The ranges
> shown are the ODX's encoding bounds, **not** validated safe operating limits.
> Writing BMS/MCU config can affect battery safety, range, thermal protection or
> brick a module. Test only on an immobilised scooter; change one value at a time;
> record originals first. `2E` = WriteDataByIdentifier, `2F` = IOControl actuator.

## 1. Head-unit self-tests (gRPC `RemoteRunTestCmd`, not UDS)
Momentary self-tests over the wifican RPC — no ECU unlock needed.

| name | what |
|---|---|
| `lcd` | LCD/display test |
| `gps` | GPS module test |
| `bt` | Bluetooth test |
| `ble` | BLE test |
| `wifi` | Wi-Fi test |
| `spkr` | speaker beep |
| `mic` | microphone test |
| `esim` | eSIM test |
| `vin-get` | read VIN |
| `mcu-cal` | motor recalibration (RED) |

## VCU — 0x786/0x7B0
Actuator tests: 52 · Writable params: 0 · Routines: 7

### VCU actuator/component tests (`2F <DID> 03 <state>`, state 01=on/00=off)
| DID | control |
|---|---|
| `03F1` | MCU digital Output 1 to MCU |
| `03F2` | MCU digital Output 2 to MCU |
| `03F3` | Vehicle CAN TRX Standby command |
| `03F4` | FC CAN TRX Standby command |
| `03F5` | HU CAN TRX Standby command |
| `03F6` | BRAKE Suppy Enable |
| `03F7` | Side Stand  switch supply control command |
| `03F8` | Seat Occupant switch supply command |
| `03F9` | SSB switch supply control command |
| `03FA` | Right Brake pad wear supply control command |
| `03FB` | Left Brake pad wear supply control Command |
| `03FC` | Spare1 Current source supply control command |
| `03FD` | Spare2 Current source supply control command |
| `03FE` | HBC 12V supply Control command |
| `03FF` | Speaker Supply Enable |
| `0400` | Steering Lock 12V supply control command |
| `0401` | Alarm 12V supply control command |
| `0402` | Seat Lock 12V supply control command |
| `0403` | Head unit 12V supply control command |
| `0404` | Charger USB 12V supply control command |
| `0405` | Front DRL 12V supply control command |
| `0406` | Front light low beam 12V supply control command |
| `0407` | Front light high beam 12V supply control command |
| `0408` | Right Indicators 12V supply control command |
| `0409` | Left Indicators 12V supply control command |
| `040A` | Rear Brake light 12V supply control command |
| `040B` | Rear Light POS 12V supply control command |
| `040C` | Boot Light 12V supply control command |
| `040D` | Spare 1 12V supply control command |
| `040E` | FC contactor +ve supply command |
| `040F` | FC contactor -ve supply command |
| `0410` | Horn 12V supply control command |
| `0411` | SPARE2 Supply 12V command |
| `0412` | Control Pilot Wire(CPW) |
| `0413` | Driver Diagnostic Enable |
| `0414` | Driver Diagnostic Select 1 |
| `0415` | Driver Diagnostic Select 2 |
| `0416` | Drivers Fault Reset |
| `0417` | SOM Volume down |
| `0418` | SOM Volume Up |
| `0419` | SOM Power Key |
| `041A` | SOM Power Boot |
| `041B` | Level Shifter Enable |
| `041C` | LIN Driver Enable |
| `041D` | 3.8V output DC-DC enabled |
| `041E` | 3V3 Enable |
| `041F` | BLE Module Reset |
| `0420` | BLE Output |
| `0421` | Status LED 1 |
| `0422` | Status LED 2 |
| `0423` | Aux Battery Charger |
| `0424` | BLE Boot |

## BMS — 0x78E/0x7B1
Actuator tests: 12 · Writable params: 178 · Routines: 1

### BMS actuator/component tests (`2F <DID> 03 <state>`, state 01=on/00=off)
| DID | control |
|---|---|
| `E707` | BMS12VSupply |
| `E708` | BMSStatus |
| `E709` | GateDriver |
| `E70A` | DischargeFET |
| `E70B` | ChargeFET |
| `E70C` | PreChargeFET |
| `E70D` | AFEReset |
| `E70E` | OverloadClear |
| `E70F` | BMS9VSupply |
| `E710` | BMS3.3VMeasure |
| `E711` | BMS3V3Voltage |
| `E712` | BMS5VVoltage |

### BMS writable parameters (`2E <DID> …`)
| DID | parameter name | fields (unit · range · step) |
|---|---|---|
| `F181` | WxApplicationSoftwareIdentificationDID | ApplicationSoftwareIdentificationDID ( · — · None) |
| `F110` | WxBMS SWFlasheddate | BMS SW flashed date ( · 0–None · 1) |
| `F191` | WxBMS_SerialNumber | BMS_SerialNumber ( · — · None) |
| `F120` | WxBatteryPackSerialNumber | Battery Pack Serial Number ( · — · None) |
| `F180` | WxBootloaderversion | Bootloader version ( · — · None) |
| `E4C3` | WxCELL_TYPE | CELL_TYPE ( · 0–None · 1) |
| `E300` | WxE300_ShuntSensorBatteryCurrent | Shunt sensor Battery current - scaling factor ( · — · 0.01)<br>Shunt sensor Battery current - offset ( · — · 0.1) |
| `E301` | WxE301_BusVoltageAfterContactor | Bus voltage after contactor - scaling factor ( · — · 0.01)<br>Bus voltage after contactor - offset ( · — · 0.1) |
| `E302` | WxE302_BatteryPackTemp_Scaling | Battery pack temperature1 - scaling factor ( · — · 0.01)<br>Battery pack temperature2 - scaling factor ( · — · 0.01)<br>Battery pack temperature3 - scaling factor ( · — · 0.01)<br>Battery pack temperature4 - scaling factor ( · — · 0.01)<br>Battery pack temperature5 - scaling factor ( · — · 0.01)<br>Battery pack temperature6 - scaling factor ( · — · 0.01) |
| `E303` | WxE303_BatteryPackTemp_Offset | Battery pack temperature1 - Offset ( · — · 0.1)<br>Battery pack temperature2 - Offset ( · — · 0.1)<br>Battery pack temperature3 - Offset ( · — · 0.1)<br>Battery pack temperature4 - Offset ( · — · 0.1)<br>Battery pack temperature5 - Offset ( · — · 0.1)<br>Battery pack temperature6 - Offset ( · — · 0.1) |
| `E304` | WxE304_CellVoltages_Scaling | Cell 1 Scaling factor ( · — · 0.01)<br>Cell 2 Scaling factor ( · — · 0.01)<br>Cell 3 Scaling factor ( · — · 0.01)<br>Cell 4 Scaling factor ( · — · 0.01)<br>Cell 5 Scaling factor ( · — · 0.01)<br>Cell 6 Scaling factor ( · — · 0.01)<br>Cell 7 Scaling factor ( · — · 0.01)<br>Cell 8 Scaling factor ( · — · 0.01)<br>Cell 9 Scaling factor ( · — · 0.01)<br>Cell 10 Scaling factor ( · — · 0.01)<br>Cell 11 Scaling factor ( · — · 0.01)<br>Cell 12 Scaling factor ( · — · 0.01)<br>Cell 13 Scaling factor ( · — · 0.01)<br>Cell 14 Scaling factor ( · — · 0.01) |
| `E305` | WxE305_CellVoltages_Offset | Cell 1 - Offset ( · — · 0.1)<br>Cell 2 - Offset ( · — · 0.1)<br>Cell 3 - Offset ( · — · 0.1)<br>Cell 4 - Offset ( · — · 0.1)<br>Cell 5 - Offset ( · — · 0.1)<br>Cell 6 - Offset ( · — · 0.1)<br>Cell 7 - Offset ( · — · 0.1)<br>Cell 8 - Offset ( · — · 0.1)<br>Cell 9 - Offset ( · — · 0.1)<br>Cell 10 - Offset ( · — · 0.1)<br>Cell 11 - Offset ( · — · 0.1)<br>Cell 12 - Offset ( · — · 0.1)<br>Cell 13 - Offset ( · — · 0.1)<br>Cell 14 - Offset ( · — · 0.1) |
| `E306` | WxE306_BalancingPathTemp | Balancing path temperature - scaling factor ( · — · 0.01)<br>Balancing path temperature - offset ( · — · 0.1) |
| `E307` | WxE307_PDUTemperatureSensor_AFE | PDU temperature sensor_AFE- scaling factor ( · — · 0.01)<br>PDU temperature sensor_AFE - offset ( · — · 0.1) |
| `E308` | WxE308_BMS_DCDCOutputVoltage | BMS DcDc output voltage - scaling factor ( · — · 0.01)<br>BMS DcDc output voltage - offset ( · — · 0.1) |
| `E309` | WxE309_PDUTemperatureSensor | PDU temperature sensor - scaling factor ( · — · 0.01)<br>PDU temperature sensor - offset ( · — · 0.1) |
| `E30A` | WxE30A_AFETemperatureSensor | AFE temperature sensor - scaling factor ( · — · 0.01)<br>AFE temperature sensor - offset ( · — · 0.1) |
| `E30B` | WxE30B_Cell4_CompensationResistanceValue | Cell4 compensation resistance value ( · 0–25.5 · 0.1) |
| `E30C` | WxE30C_Cell8_CompensationResistanceValue | Cell8 compensation resistance value ( · 0–25.5 · 0.1) |
| `E30D` | WxE30D_Cell11_CompensationResistanceValue | Cell11 compensation resistance value ( · 0–25.5 · 0.1) |
| `E30E` | WxE30E_NumberOfSamples | AFE_NumberOfSamples_Averaged ( · 0–255 · 1) |
| `E400` | WxE400_CPM_C_CRATE_CHGTEMPSRFT | Temperature sensor fault charge rate (in C) (C · 0–1 · 0.1) |
| `E401` | WxE401_CPM_mV_VGLT_CHGTEMPSRFT | Temperature sensor fault charge voltage limit (mV · 0–4500 · 1) |
| `E402` | WxE402_CPM_C_MAXDRVCRT_TEMPSRFL | Maximum drive c rate while temperature sensor fails (C · 0–1 · 0.1) |
| `E403` | WxE403_CPM_C_MAXDRVCRT_VGSRFL | Maximum drive c rate while  voltage sensor fails (C · 0–1 · 0.1) |
| `E404` | WxE404_CPM_%_DRVSOCLT_TEMPSRFL | Temperature sensor failure drive SoC limit (% · 0–100 · 1) |
| `E405` | WxE405_CPM_MV_MINCLVG_VGOUTOFRNGE | Voltage out of range minimum threshold (mV · 0–4500 · 1) |
| `E406` | WxE406_CPM_MV_MAXCLVG_VGOUTOFRNGE | Voltage out of range maximum threshold (mV · 0–4500 · 1) |
| `E407` | WxE407_CPM_SEC_DEBTIME_VGOUTOFRNGE | Voltage out of range debounce time (sec · 0–255 · 1) |
| `E408` | WxE408_CPM_DEGC_MINPCKTEMP_OUTOFRNGE | Temperature Out of range minimum threshold (deg C · -50–200 · 1) |
| `E409` | WxE409_CPM_DEGC_MAXPCKTEMP_OUTOFRNGE | Temperature Out of range Maximum threshold (deg C · -50–200 · 1) |
| `E40C` | WxE40C_CPM_SEC_MAXTIME_VGOUTOFRNGE | Voltage out of range Maximum time Duration (sec · 0–200 · 1) |
| `E40D` | WxE40D_CPM_SEC_MAXTIME_TEMPOUTOFRNGE | Temperature out of range  Maximum time Duration (sec · 0–200 · 1) |
| `E40E` | WxE40E_CPM_DEGC_MAXTEMP_EFFPCK | Maximum temperaure threshold value to derive pack effective temperature (deg C · -50–200 · 1) |
| `E40F` | WxE40F_CPM_DEGC_MAXDELTATEMP_EFFPCK | Effective temperature delta threshold (deg C · -50–200 · 1) |
| `E410` | WxE410_CPM_DEGC_MINTEMP_EFFPCK | Minimum temperature threshold value to derive pack effective temperature (deg C · -50–200 · 1) |
| `E414` | WxE414_SLC_MV_THDVTG_CELL | Cell voltage threshold for CC end mode. (mV · 0–4500 · 1) |
| `E415` | WxE415_SLC_SEC_DEBTIME_ENDCCMD | CC end mode debounce time (sec · 0–250 · 1) |
| `E416` | WxE416_SLC_SEC_WAITDUR_AFTRCCMD | Wait duration after CC mode. (sec · 0–250 · 1) |
| `E417` | WxE417_SLC_MV_DEVVTG_CELLBLNG | Cell voltage deviation to start cell balancing (mV · 0–2500 · 1) |
| `E418` | WxE418_SLC_SEC_DEBTIME_STRTSTPCELLBLNG | Debounce period to start/stop cell balancing (sec · 0–250 · 1) |
| `E419` | WxE419_SLC_A_THSDCURR_ENDCV | Current threshold to end CV mode (A · -120–120 · 0.1) |
| `E41A` | WxE41A_SLC_SEC_DEBDUR_ENDCV | Debounce duration to end CV mode (sec · 0–250 · 1) |
| `E41B` | WxE41B_SLC_DEGC_HIGHTEMP_STPCHG | Charge stop high temperature (degC · -50–200 · 1) |
| `E41C` | WxE41C_SLC_DEGC_HIGHTEMP_RESMCHG | Charge resume high temperature (degC · -50–200 · 1) |
| `E41D` | WxE41D_SLC_DEGC_LOWTEMP_STPCHG | Charge stop low temperature (degC · -50–200 · 1) |
| `E41E` | WxE41E_SLC_%_SOC_RESTRTCHG | Charge re-start SOC (% · 0–100 · 1) |
| `E41F` | WxE41F_SLC_A_OVERCURR_TOLCHG | Charge over current tolerance (A · -120–120 · 0.1) |
| `E420` | WxE420_SLC_SEC_DEBTIME_CHGOC | Charge over current debounce time (sec · 0–250 · 1) |
| `E422` | WxE422_SLC_CNT_CNTR_CURRMSMTCH | Current mismatch counter (Cnt · 0–250 · 1) |
| `E423` | WxE423_SLC_DEGC_LOWTEMP_RESCHG | Charge resume low temperature (degC · -50–200 · 1) |
| `E424` | WxE424_SLC_MV_THVG_STRTBALCELL | Cell voltage threshold to start balancing (mV · 0–4500 · 1) |
| `E425` | WxE425_SLC_MV_MINVG_STRTCELLBAL | Cell minimum voltage  to start balancing (mV · 0–4500 · 1) |
| `E427` | WxE427_SLC_MV_VGDEV_STPCELLBAL | Cell voltage deviation to stop cell balancing (mV · 0–4500 · 1) |
| `E428` | WxE428_SLC_V_RTRMPUPVG_PRGVG | Rate of ramp up of programming voltage (V · 0–60 · 0.1) |
| `E429` | WxE429_SLC_A_DIFFCURR_BATANDPRG | Accepted difference between battery current and programming current (A · -120–120 · 0.1) |
| `E42E` | WxE42E_SLC_DEGC_BALANCESTART_TEMP | Balance start temperature threshold (degC · -50–200 · 1) |
| `E42F` | WxE42F_SLC_SEC_BALANCETEMP_DEB | Balance temperature debounce time (sec · 0–250 · 1) |
| `E430` | WxE430_SLC_DEGC_BALANCESTOP_TEMP | Balance stop temperature threshold (degC · -50–200 · 1) |
| `E431` | WxE431_SLC_A_DERATE_CURRENT | Derate current limit during overcurrent charge warning (A · 0–120 · 1) |
| `E432` | WxE432_SOC_A_THSDCURR_OCV | SoC OCV current threshold (A · 0–5 · 0.1) |
| `E433` | WxE433_SOC_SEC_RESTPERD_OCV | SoC OCV rest period (sec · 0–3600 · 1) |
| `E434` | WxE434_SOC_AH_USECAP_PCK | Usable capacity (Ah · 0–44 · 0.1) |
| `E435` | WxE435_SOC_CNT_PCKCNT_VEH | Intended no of packs in vehicle (Cnt · 1–5 · 1) |
| `E436` | WxE436_SOC_SEC_TIME_SOCRMP | SoC ramp time (sec · 0–250 · 1) |
| `E437` | WxE437_SWF_MIN_DUR_PCKWKUP | Pack wakeup duration (min · 0–1440 · 1) |
| `E438` | WxE438_SWF_SEC_TM_WKUPELPSE | Wake time elapsed threshold (sec · 0–1000 · 1) |
| `E439` | WxE439_SWF_A_THSDCURR_AFTRBMSWKUP | Current threshold after BMS wakes up (A · -120–120 · 0.1) |
| `E43A` | WxE43A_SWF_SEC_TM_NODEABSENTDISC | Node absent disconnect timer (sec · 0–250 · 1) |
| `E43B` | WxE43B_BAF_MV_SOH_LWRTHSD | SoH lower threshold (mV · 3000–5000 · 10) |
| `E43C` | WxE43C_BAF_MV_SOH_UPRTHSD | SoH upper threshold (mV · 3000–5000 · 10) |
| `E43D` | WxE43D_BAF_CNT_CORRTNFCTR_SOH | SoH correction factor (Cnt · 0–1 · 0.01) |
| `E43E` | WxE43E_BCD_%_THSDSOC_PCHG | Precharge threshold (% · 0–100 · 1) |
| `E43F` | WxE43F_BCD_MS_THSDREPTIME_PCHGTOOFST | Time threshold to report precharge too fast (ms · 0–5000 · 50) |
| `E440` | WxE440_BCD_MS_MINREPTIME_PCHGTOOSLW | Minimum time to report precharge too slow (ms · 0–5000 · 50) |
| `E441` | WxE441_BCD_MS_THSDREPTIME_PCHGFLR | Time threshold to report precharge failure (ms · 0–5000 · 50) |
| `E443` | WxE443_BCD_MS_DELAYTIME_TRNOFFPCHGFET | Time delay to turn OFF precharge FET (ms · 0–5000 · 50) |
| `E449` | WxE449_BCD_DEGC_THSDTEMP_PDUWARNG | PDU temperature - warning threshold (degC · -50–200 · 1) |
| `E44A` | WxE44A_BCD_DEGC_THSDTEMP_PDUERROR | PDU temperature - error threshold (degC · -50–200 · 1) |
| `E44D` | WxE44D_BCD_SEC_WTTIME_HVDICON | HV Disconnect wait time (sec · 0–250 · 1) |
| `E451` | WxE451_BCD_MS_WTTIME_HVCONCONFIRM | HV connect confirmation wait time (ms · 0–250 · 10) |
| `E452` | WxE452_BCD_MS_WTTIME_HVDISCONCONFIRM | HV disconnect confirmation wait time (ms · 0–250 · 10) |
| `E455` | WxE455_SAF_MS_DEBTIME_VG | Voltage debounce time (ms · 0–10000 · 50) |
| `E456` | WxE456_SAF_MV_CHGOVERVG_HEAL | Charge over voltage heal (mV · 0–4500 · 5) |
| `E457` | WxE457_SAF_MV_CHGOVERVG_ERROR | Charge over voltage Error (mV · 0–4500 · 5) |
| `E459` | WxE459_SAF_MV_CURR_CHGOVERVGFL | Charge over voltage permanent failure (mV · 0–4500 · 5) |
| `E45A` | WxE45A_SAF_MV_OVERVGLT_REGEN | Regen over voltage limit (mV · 0–4500 · 5) |
| `E45C` | WxE45C_SAF_MV_UNDERVG_WARNG | Under voltage warning (mV · 0–4500 · 5) |
| `E45F` | WxE45F_SAF_MV_UNDERVG_RESM | Under voltage resume (mV · 0–4500 · 5) |
| `E460` | WxE460_SAF_MV_UNDERVG_ERROR | Under voltage error (mV · 0–4500 · 5) |
| `E461` | WxE461_SAF_MV_UNDERVG_PERMNTFT | Under voltage permanant fault (mV · 0–4500 · 5) |
| `E462` | WxE462_SAF_DEGC_OVERTEMP_CHGWARNG | Over temperature charge warning (deg C · -50–200 · 1) |
| `E463` | WxE463_SAF_MS_DEBTIME_TEMP | Temperature debounce time (ms · 0–5000 · 100) |
| `E464` | WxE464_SAF_DEGC_OVERTEMP_CHGWARNGRESM | Over temperature charge warning resume (deg C · -50–200 · 1) |
| `E465` | WxE465_SAF_DEGC_OVERTEMP_CHGERROR | Over temperature charge error (deg C · -50–200 · 1) |
| `E466` | WxE466_SAF_DEGC_OVERTEMP_CHGERRORRESM | Over temperature charge error resume (deg C · -50–200 · 1) |
| `E467` | WxE467_SAF_DEGC_OVERTEMP_DRVWARNG | Over temperature drive warning (deg C · -50–200 · 1) |
| `E468` | WxE468_SAF_DEGC_OVERTEMP_DRVWARNGRESM | Over temperature drive warning resume (deg C · -50–200 · 1) |
| `E469` | WxE469_SAF_DEGC_OVERTEMP_DRVERROR | Over temperature drive error (deg C · -50–200 · 1) |
| `E46A` | WxE46A_SAF_DEGC_OVERTEMP_DRVERRORRESM | Over temperature drive error resume (deg C · -50–200 · 1) |
| `E46B` | WxE46B_SAF_DEGC/SEC_CLVENTTEMPRISERT_PERMFT | Cell vent temperature rise rate permanent fault (deg C/sec · 0.1–1 · 0.01) |
| `E46C` | WxE46C_SAF_DEGC_TEMPTHSD_CELLVENT | Cell vent temperature threshold (deg C · -50–200 · 1) |
| `E46D` | WxE46D_SAF_DEGC/SEC_CELLVENTTEMPRISERATE_ERR | Cell vent temperature rise rate for error condition (deg C/sec · 0.1–1 · 0.01) |
| `E46E` | WxE46E_SAF_CNT_ERRORCNTR_CELLVENT | Cell vent error counter (cnt · 0–250 · 1) |
| `E46F` | WxE46F_SAF_SEC_ERRORTMR_CELLVENT | Cell vent error timer (sec · 0–250 · 1) |
| `E470` | WxE470_SAF_A_THSDCURR_SHRTCRCT | Short circuit current threshold (A · 0–1000 · 1) |
| `E471` | WxE471_SAF_MS_DETTIME_SHRTCRCT | Short circuit detection time (ms · 0–1000 · 5) |
| `E472` | WxE472_SAF_SEC_DETDUR_SHRTCRCTERROR | Short circuit detection duration for error (sec · 0–250 · 1) |
| `E473` | WxE473_SAF_CNT_ERRORCNTR_SHRTCRCT | Short circuit error counter (cnt · 0–250 · 1) |
| `E474` | WxE474_SAF_DEGC_LOWTEMP_CHGERROR | Low temperature charge error (deg C · -50–200 · 1) |
| `E475` | WxE475_SAF_DEGC_LOWTEMP_CHGERRORRESM | Low temperature charge error resume (deg C · -50–200 · 1) |
| `E476` | WxE476_SAF_DEGC_LOWTEMP_DRVERROR | Low temperature drive error (deg C · -50–200 · 1) |
| `E477` | WxE477_SAF_DEGC_LOWTEMP_DRVERRORRESM | Low temperature drive error resume (deg C · -50–200 · 1) |
| `E478` | WxE478_SAF_MV_VGDEV_CELLFAIL | Voltage deviation for cell failure (mV · 0–4500 · 5) |
| `E479` | WxE479_SAF_%_SOCRISELT_MONITORCELLVG | Cell failure change in voltage monitoring SOC rise (% · 0–100 · 1) |
| `E47A` | WxE47A_SAF_%_SOCLRLT_CELLFL | Cell failure SoC lower limit (% · 0–100 · 1) |
| `E47B` | WxE47B_SAF_%_SOCUPPRLT_CELLFL | Cell failure SoC upper limit (% · 0–100 · 1) |
| `E47C` | WxE47C_SAF_DEGC_TEMPLRLT_CELLFL | Cell failure temperature lower limit (degC · -50–200 · 1) |
| `E47D` | WxE47D_SAF_DEGC_TEMPUPPRLT_CELLFL | Cell failure temperature upper limit (degC · -50–200 · 1) |
| `E47E` | WxE47E_SAF_CNT_FTCNTR_CELLFAIL | Cell failure fault counter (cnt · 0–250 · 1) |
| `E483` | WxE483_SAF_SEC_TEMP_VENT | Cell temperature monitoring rate for cell vent detection (sec · 0–250 · 1) |
| `E484` | WxE484_SAF_A_CELLVENT_DERATE | Cell vent failure derate current limit (A · 0–200 · 1) |
| `E485` | WxE485_DRM_MV_REGEN_START | Regen start cell voltage (mV · 0–5000 · 1) |
| `E486` | WxE486_DRM_%_CAP_REGEN | Allowed regen capacity percentage (% · 0–100 · 1) |
| `E487` | WxE487_DRM_MV_REGEN_STOP | Regen stop max cell voltage (mV · 0–5000 · 1) |
| `E48B` | WxE48B_DRM_CONST_FAC_30 | Drive current limit 30sec factor (Cnt · 0–1 · 0.01) |
| `E48C` | WxE48C_DRM_CONST_FAC_60 | Drive current limit 60sec factor (Cnt · 0–1 · 0.01) |
| `E48D` | WxE48D_UMC_A_LOWCURR_DETTHSD | Low current detection threshold (A · -5–5 · 0.01) |
| `E48E` | WxE48E_UMC_A_DEFCURR_SLEEP | Default current sleep (A · -5–5 · 0.01) |
| `E48F` | WxE48F_UMC_A_DEFCURR_PDUCONTD | Default current PDU connected (A · -5–5 · 0.01) |
| `E490` | WxE490_UMC_A_DEFCURR_PDUDISCONTD | Default current PDU disconnected (A · -5–5 · 0.01) |
| `E493` | WxE493_FED_BIT_EN_CHGRESTRT | Charge restart Enable ( · 0–1 · 1) |
| `E494` | WxE494_FED_BIT_EN_CVCHG | CV Phase charge Enable ( · 0–1 · 1) |
| `E495` | WxE495_FED_BIT_EN_BAL | Balancing Enable ( · 0–1 · 1) |
| `E498` | WxE498_TTC_MIN_CVCHRG_RTDTIME | Rated time to charge in CV phase (min · 0–255 · 1) |
| `E49B` | WxE49B_SYS_PER_DEPTHOFDISCH | Depth of Discharge (% · 0–100 · 1) |
| `E49C` | WxE49C_UDS_SEC_READ_PACKDATA | Duration to read pack temperature during diagnostics (sec · 0–255 · 1) |
| `E49E` | WxE49E_UDS_A_CHGCURR_CCPHASE | Capacity test charge current limit at cc phase (A · 0–120 · 0.01) |
| `E49F` | WxE49F_UDS_MV_MAXVG_CCSTP | Capacity test cc phase stop maximum cell voltage (mV · 0–4200 · 1) |
| `E4A0` | WxE4A0_UDS_DEGC_MINTEMP_CHGSTRT | Capacity test charge start minimum temperature (degC · -50–200 · 1) |
| `E4A1` | WxE4A1_UDS_DEGC_MAXTEMP_CHGSTRT | Capacity test charge start maximum temperature (degC · -50–200 · 1) |
| `E4A2` | WxE4A2_BCD_CNT_MSFTCNTCN_WRGNG | MOSFET connection warning counter (Cnt · 0–10 · 1) |
| `E4A3` | WxE4A3_BCD_A_DERCURR_PDUTEMP | PDU temperature warning derate current (A · 0–120 · 0.01) |
| `E4A4` | WxE4A4_SAF_DEGC_LOWTEMP_CHGWRNG | Low temperature charge warning (degC · -50–200 · 1) |
| `E4A5` | WxE4A5_SAF_DEGC_LOWTEMP_DRVEWRNG | Low temperature drive warning (degC · -50–200 · 1) |
| `E4A6` | WxE4A6_SAF_DEGC_MINTEMP_CELLDSCNT | Minimum temperature to start cell disconnection test (degC · -50–200 · 1) |
| `E4A7` | WxE4A7_SAF_DEGC_MAXTEMP_CELLDSCNT | Maximum temperature to start cell disconnection test (degC · -50–200 · 1) |
| `E4A8` | WxE4A8_SAF_%_SOCLOWERLIMIT_STARTTEST | SOC lower limit to start cell disconnection test (% · 1–100 · 1) |
| `E4A9` | WxE4A9_SAF_%_SOCHIGHERLIMIT_STARTTEST | SOC higher limit to start cell disconnection test (% · 1–100 · 1) |
| `E4AA` | WxE4AA_SAF_AH_CHANGE_INAH | Ah change interval for cell voltage change check in disconnection test (mAh · 0–9000 · 1) |
| `E4AB` | WxE4AB_SAF_MV_MAXDEVIATION_CELLDISCNFT | Maximum cell voltage deviation to determine cell disconnection fault (mV · 0–5000 · 1) |
| `E4B0` | WxE4B0_FC_MINS_MAXTIME_CHG | Maximum charging time permitted by EV (min · 0–65534 · 1) |
| `E4B1` | WxE4B1_FC_V_MAXVTG_DCOUTPUT | Maximum DC output voltage limit by EV (V · 0–80 · 0.1) |
| `E4B2` | WxE4B2_BCD_%_MINSOC_HVCON | Minimum SOC to connect HV (% · 0–100 · 1) |
| `E4B3` | WxE4B3_SAF_A_DERCURR_UNDERVG | Under voltage current derate value (A · 0–200 · 1) |
| `E4B4` | WxE4B4_DRM_SEC_WTPERD_CONT | Wait period in continuous drive current limit (sec · 0–250 · 1) |
| `E4B6` | WxE4B6_BCD_V_VTGLT_HVDISCONCONFIRM | HV disconnect confirmation voltage limit (mV · 0–250 · 1) |
| `E4B7` | WxE4B7_BCD_%_DROP_BUSVTG | Bus voltage drop percentage to confirm HV disconnect (% · 0–100 · 1) |
| `E4B8` | WxE4B8_BCD_%_CONFIRM_HVCON | Pack voltage percentage to confirm HV connect (% · 0–100 · 1) |
| `E4B9` | WxE4B9_SAF_MS_DEBTIME_SHRTCRCT | Debounce time for short circuit error detection (ms · 0–250 · 10) |
| `E4BA` | WxE4BA_PARALLEL_CNT_CELL_STRING | Number of parallel cells in a pack (Cnt · 1–20 · 1) |
| `E4BC` | WxE4BC_EnableDisable_RegenLimit | Regeneration limit Enable/Disable ( · 0–1 · 1) |
| `E4BD` | WxE4BD_SLC_FLG_CANCHRGACTIVE | Can Charging Enable or Disable ( · 0–1 · 1) |
| `E4BE` | WxE4BE_SLC_SEC_DEBTIME_ENDCVCMD | CV end mode debounce time (sec · 0–250 · 1) |
| `E4BF` | WxE4BF_FaultManagement_Switch | FMC_FLG_CELLVLTG_OOR_ACTV ( · 0–1 · None)<br>FMC_FLG_TEMP_OOR_ACTV ( · 0–1 · None)<br>FMC_FLG_CHRGOVRVLTG_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_CHRGOVRVLTG_PERM_ACTV ( · 0–1 · None)<br>FMC_FLG_RGNWARN_ACTV ( · 0–1 · None)<br>FMC_FLG_RGNERR_ACTV ( · 0–1 · None)<br>FMC_FLG_UVWARN_ACTV ( · 0–1 · None)<br>FMC_FLG_UVERR_ACTV ( · 0–1 · None)<br>FMC_FLG_UVPERM_ACTV ( · 0–1 · None)<br>FMC_FLG_OTCHRG_WARN_ACTV ( · 0–1 · None)<br>FMC_FLG_OTCHRG_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_OTDRV_WARN_ACTV ( · 0–1 · None)<br>FMC_FLG_OTDRV_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_LOWTCHRG_WARN_ACTV ( · 0–1 · None)<br>FMC_FLG_LOWTCHRG_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_LOWTDRV_WARN_ACTV ( · 0–1 · None)<br>FMC_FLG_LOWTDRV_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_PRECHRGTOOFAST_ACTV ( · 0–1 · None)<br>FMC_FLG_PRECHRGTOOSLOW_ACTV ( · 0–1 · None)<br>FMC_FLG_PRECHRGFLT_ACTV ( · 0–1 · None)<br>FMC_FLG_MSFTCONNFLT_ACTV ( · 0–1 · None)<br>FMC_FLG_MSFTDISCONNFLT_ACTV ( · 0–1 · None)<br>FMC_FLG_PDUTEMPERR_ACTV ( · 0–1 · None)<br>FMC_FLG_OC_CHRGWARN_ACTV ( · 0–1 · None)<br>FMC_FLG_SHRTCKTDTCTN_ERR_ACTV ( · 0–1 · None)<br>FMC_FLG_SHRTCKTDTCTN_PERM_ACTV ( · 0–1 · None)<br>FMC_FLG_TEMPSENS_CHRGWARN_ACTV ( · 0–1 · None)<br>FMC_FLG_TEMPSENS_CHRGERR_ACTV ( · 0–1 · None)<br>FMC_FLG_TEMPSENS_DRVWARN_ACTV ( · 0–1 · None)<br>FMC_FLG_TEMPSENS_DRVERR_ACTV ( · 0–1 · None)<br>Reserved ( · 0–1 · None)<br>Reserved ( · 0–1 · None) |
| `E4C0` | WxE4C0_SOC_AH_USECAP_CELL | Usable capacity per cell (Ah · 0–100 · 0.01) |
| `E4C1` | WxE4C1_TTC_AH_RTD_CELLCAP | Rated capacity per cell (Ah · 0–100 · 0.01) |
| `E4C2` | WxE4C2_TTC_AH_RTD_CELLCVCAP | Rated capacity to be filled in CV phase per cell (Ah · 0–100 · 0.01) |
| `E4C3` | WxE4C3_CELL_TYPE | CELL_TYPE ( · 0–1 · 1) |
| `E4C4` | WxE4C4_SLC_MV_THDVTG_CCEND_CELL | Threshold cell voltage to stop CC charge mode (mV · 2500–4500 · 1) |
| `E4C5` | WxE4C5_SLC_MV_THDVTG_CHRGEND_CELL | Threshold cell voltage to complete charging (mV · 2500–4500 · 1) |
| `E4C6` | WxE4C6_SLC_PCT_SOC_RESTRTCHG | SoC in percentage below which charging shall be restarted when Charger is plugged in (% · 0–100 · 1) |
| `E4C7` | WxE4C7_EOL_SessionControl | EOL Mode ( · — · None)<br>Timeout value for which BMS should hold this EOL Session (s · 0–65535 · 1) |
| `E4C8` | WxE4C8_ACC_I_CONSTDSCHCURRLMT | ACC_I_CONSTDSCHCURRLMT (cnt · 0–500 · 1) |
| `E4C9` | WxE4C9_CSC_MV_CELLVLTG_FULLSOC | CSC_MV_CELLVLTG_FULLSOC (mv · 0–5000 · 1) |
| `E4CA` | WxE4CA_SLC_I_CHRGCMPLT_CURR | SLC_I_CHRGCMPLT_CURR (A · 0–5 · 0.1) |
| `E4CB` | WxE4CB_SLC_V_VLTGOFST_CV | SLC_V_VLTGOFST_CV (V · 0–2 · 0.1) |
| `E4CC` | WxE4CC_SLC_SEC_WAITDUR_CVREST | SLC_SEC_WAITDUR_CVREST (Sec · 0–120 · 1) |

## MCU — 0x7A6/0x7B4
Actuator tests: 0 · Writable params: 8 · Routines: 3

### MCU writable parameters (`2E <DID> …`)
| DID | parameter name | fields (unit · range · step) |
|---|---|---|
| `B103` | WxB103_Torque setting | Torque setting (% · 0–200 · 0.1) |
| `B10B` | WxB10B_RegenCurrentLimit | coasting regen start speed (Hz · 0–320 · 0.1)<br>brake regen current limit (% · 0–100 · 0.1)<br>coast regen current limit (% · 0–100 · 0.1) |
| `B10D` | WxB10D_ThrottleSamplingLimit | Throttle sampling value (- · 0–65535 · 1)<br>Throttle min. value (- · 0–30000 · 1)<br>Throttle max. value (- · 0–30000 · 1) |
| `B110` | WxB110_Vehicle_Mode_Torque_Limit | Eco Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Normal Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Sport Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Boost Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Reverse Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Limphome Mode Torque Limit (A · 0–6553.5 · 0.1)<br>Turbo Mode Torque Limit (A · 0–6553.5 · 0.1) |
| `B110` | WxB111_Acceleration_Time_Configuration | Other drive mode accleration time (S · 0–2.5 · 0.01)<br>Turbo mode accleration time (S · 0–2.5 · 0.01) |
| `B112` | WxB112_LimpHome Speed Limit | LimpHome Speed Limit (% · 0–100 · 0.1) |
| `B113` | WxB113_AngleofSynchronousMotor | Initial angle of Synchronous motor (° · 0–360 · 0.1) |
| `F180` | WxF180_BootSoftwareIdentificationDataIdentifier | BootSoftwareIdentificationDataIdentifier ( · — · None)<br>DC bus current setting (+) (A · 0–300 · 0.1)<br>DC bus current setting (-) (A · 0–300 · 0.1) |

---

## Ride modes — corrected source audit (2026-09-11)

No verified procedure to enable a separate Turbo riding mode on this MY2022 scooter has been established. Hyper = Boost remains unverified. Calibration field order is not a CAN mode enum.

### What the diagnostic sources establish

- ODX MCU B110 has seven named torque-limit fields: Eco, Normal, Sport, Boost, Reverse, Limphome, Turbo. These are calibration slots, not mode-selection commands. The acceleration write also uses request DID B110 despite its B111 label; this conflict remains unresolved.
- live_parameters.json maps CAN 143 Vehicle_Mode_Level_4 as 00 SNA, 01 ECO, 02 NORMAL, 03 SPORT, 04 BOOST, 05 REVERSE, 06 TURBO. The DBC puts this four-bit status field at start bit 12.
- Vehicle_Mode_Level_1 = 3 means Slow Charge, NOT Hyper. The previous catalog's claimed live confirmation was incorrect.
- A separate live_parameters.json mapping for CAN 6AD Drive_Mode lists values 0 through 5, but the DBC defines that signal as a one-bit button input. These sources conflict; do not treat this as a verified mode command.
- No direct VCU 2E enable-Turbo parameter was found in this ODX. Writing a torque calibration does not select or expose its mode.

### Separate consumer-app TurboBoost feature

The extracted consumer app contains CustomizationSettingsType$TurboBoostSettings with default type 4, and TurboBoostState OFF=0 / ON=1. CustomizationSettingsType.processByteArrayLogic serializes the state as one byte; CustomizationSettingsCommand.commandData prepends the type. Thus the inner data is 04 00 / 04 01. This command inherits EncryptedRequest: these two bytes are NOT a complete BLE packet or CAN command.

Source files are in reverse_engineering/consumer_app under domain.domainModels.ble.customizationSettings.*. This proves a consumer-app feature exists, but does not establish compatibility with this vehicle, its eligibility rules, or any connection to the diagnostic MCU Turbo calibration slot.

### Remaining evidence needed

Trace the consumer app feature eligibility and encrypted request/response flow, and establish the vehicle-side implementation or supported response for this model. For Hyper/Boost naming, a timestamped passive Level_4 capture tied to the displayed rider mode can validate the mapping. No vehicle commands were sent in this audit.

The previous suggestions to raise B110 limits or inject mode index 6 were unsupported ways to obtain Turbo and have been withdrawn. APK development remains a later phase.
