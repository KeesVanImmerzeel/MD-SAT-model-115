library Dsmodel115;
  {-Berekening nat-, droogte- en totale schade aan landbouwgewassen
    afhankelijk van gewas, bodemtype, GHG en GLG. Zie
    "BESCHRIJVING FUNCTIONALITEIT REKENHART WATERNOOD 2007 STOWA,
    versie 1 december 2006"}

  { Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  ShareMem,
  windows,
  SysUtils,
  Classes,
  LargeArrays,
  ExtParU,
  USpeedProc,
  uDCfunc,
  UdsModel,
  UdsModelS,
  xyTable,
  DUtils,
  uError,
  Math;

Const
  cModelID      = 115;  {-Uniek modelnummer}

  {-Beschrijving van de array met afhankelijke variabelen}
  cNrOfDepVar   = 3;    {-Lengte van de array met afhankelijke variabelen}
  cy1           = 1;    {-GEMIDDELDE Natschade (%)}
  cy2           = 2;    {-GEMIDDELDE Droogteschade (%)}
  cy3           = 3;    {-GEMIDDELDE opbrengstdepressie door nat- EN
                          droogteschade (=Doelrealisatie, %)}

  {-Aantal keren dat een discontinuiteitsfunctie wordt aangeroepen in de procedure met
    snelheidsvergelijkingen (DerivsProc)}
  nDC = 0;

  {-Variabelen die samenhangen met het aanroepen van het model vanuit de Shell}
  cnRP    = 4;   {-Aantal RP-tijdreeksen die door de Shell moeten worden aangeleverd (in
                   de externe parameter Array EP (element EP[ indx-1 ]))}
  cnSQ    = 0;   {-Idem punt-tijdreeksen}
  cnRQ    = 0;   {-Idem lijn-tijdreeksen}

  {-Beschrijving van het eerste element van de externe parameter-array (EP[cEP0])}
  cNrXIndepTblsInEP0 = 2018;  {-Aantal XIndep-tables in EP[cEP0]}
  cNrXdepTblsInEP0   = 0;  {-Aantal Xdep-tables   in EP[cEP0]}
  {-Nummering van de xIndep-tabellen in EP[cEP0]. De nummers 0&1 zijn gereserveerd}
  cTb_MinMaxValKeys            = 2;

  {-Beschrijving van het tweede element van de externe parameter-array (EP[cEP1])}
  {-Opmerking: table 0 van de xIndep-tabellen is gereserveerd}
  {-Nummering van de xdep-tabellen in EP[cEP1]}
  cTb_Gewas     = 0; {(=gewas, 1-14}
  cTb_Bodemtype = 1; {1-72}
  cTb_GHG       = 2; {m-mv}
  cTb_GLG       = 3; {m-mv}

  {-Model specifieke fout-codes DSModel113: -9840..-9849}
  {cInvld_KeyValue1     = -###;
  cInvld_KeyValue2     = -###;
                 ###}
  cInvld_ParFromShell_Gewas = -9840;
  cInvld_ParFromShell_Bodemtype = -9841;
  cInvld_ParFromShell_GHG = -9842;
  cInvld_ParFromShell_GLG = -9843;
  cInvld_ParFromShell_Soil_Crop_Combination = -9844;
  cInvld_ParFromShell_GxG_combi_DomainA = -9845;
  cInvld_ParFromShell_GxG_combi_DomainB = -9846;
  cInvld_ParFromShell_GxG_combi_DomainD = -9847;
  cInvld_ParFromShell_GxG_combi_DomainE = -9848;
  cInvld_ParFromShell_GxG_combi         = -9849; {-Bij opgegeven GxG geen schade getabelleerd}

                 {###
  cInvld_DefaultPar1   = -###;
  cInvld_DefaultPar2   = -###;
                 ###
  cInvld_Init_Val1     = -###;
  cInvld_Init_Val2     = -###;
                 ###}

   cNoResult = -999;

var
  Indx: Integer; {-Door de Boot-procedure moet de waarde van deze index worden ingevuld,
                   zodat de snelheidsprocedure 'weet' waar (op de externe parameter-array)
				   hij zijn gegevens moet zoeken}
  ModelProfile: TModelProfile;
                 {-Object met met daarin de status van de discontinuiteitsfuncties
				   (zie nDC) }

  {-Globally defined parameters from EP[0]}
  {###}

  {-Geldige range van key-/parameter/initiele waarden. De waarden van deze  variabelen moeten
    worden ingevuld door de Boot-procedure}
  cMin_KeyValue_Gewas, cMax_KeyValue_Gewas,
  cMin_KeyValue_Bodemtype, cMax_KeyValue_Bodemtype : Integer;
  cMin_ParValueGHG, cMax_ParValueGHG,
  cMin_ParValueGLG, cMax_ParValueGLG{,
  cMin_InitVal1,  cMax_InitVal1,  ###,} : Double;

Procedure MyDllProc( Reason: Integer );
begin
  if Reason = DLL_PROCESS_DETACH then begin {-DLL is unloading}
    {-Cleanup code here}
	if ( nDC > 0 ) then
      ModelProfile.Free;
  end;
end;


Procedure DerivsProc( var x: Double; var y, dydx: TLargeRealArray;
                      var EP: TExtParArray; var Direction: TDirection;
                      var Context: Tcontext; var aModelProfile: PModelProfile; var IErr: Integer );
{-Deze procedure verschaft de array met afgeleiden 'dydx', gegeven het tijdstip 'x' en
  de toestand die beschreven wordt door de array 'y' en de externe condities die beschreven
  worden door de 'external parameter-array EP'. Als er geen fout op is getreden bij de
  berekening van 'dydx' dan wordt in deze procedure de variabele 'IErr' gelijk gemaakt aan de
  constante 'cNoError'. Opmerking: in de array 'y' staan dus de afhankelijke variabelen,
  terwijl 'x' de onafhankelijke variabele is (meestal de tijd)}
var
  Gewas, Bodemtype: Integer;     {-Sleutel-waarden voor de default-tabellen in EP[cEP0]}
  GHG, GLG,                      {-Parameter-waarden afkomstig van de Shell}
  {DefaultPar1, DefaultPar2,}    {-Default parameter-waarden in EP[cEP0]}
  {CalcPar1, CalcPar2, ###}      {-Afgeleide (berekende) parameter-waarden}
  NatschadePerc,                 {-Berekeningsresultaat: natschade (%)}
  DroogteschadePerc,             {-Berekeningsresultaat: droogteschade (%)}
  TotaleSchadePerc: Double;      {-Berekeningsresultaat: totale schade (%)}
  iTableNat, iTableDroog,        {-Tabelnr. voor opzoeken c.q. berekenen van resp. nat- en droogteschade}
  iRow, iCol,                    {-Rij- resp. colomnr. voor opzoeken nat- en droogteschade}
  NRows, NCols,                  {-Aant. rijen en kolommen in nat- of droogteschadetabel}
  i: Integer;

Function SetParValuesFromEP0( var IErr: Integer ): Boolean;
  {-Fill globally defined parameters from EP[0]. If memory is allocated here,
    free first with 'try .. except' for those cases that the model is used repeatedly}
begin
  Result := true;
end;

Function SetKeyAndParValues( var IErr: Integer ): Boolean;

  Function GetKeyValue_Gewas( const x: Double ): Integer;
  begin
    with EP[ indx-1 ].xDep do
      Result := Trunc( Items[ cTb_Gewas ].EstimateY( x, Direction ) );
  end;

  Function GetKeyValue_Bodemtype( const x: Double ): Integer;
  begin
    with EP[ indx-1 ].xDep do
      Result := Trunc( Items[ cTb_Bodemtype ].EstimateY( x, Direction ) );
  end;

  Function GetParFromShell_GHG( const x: Double ): Double;
  begin
    with EP[ indx-1 ].xDep do
      Result := Items[ cTb_GHG ].EstimateY( x, Direction );
  end;

  Function GetParFromShell_GLG( const x: Double ): Double;
  begin
    with EP[ indx-1 ].xDep do
      Result := Items[ cTb_GLG ].EstimateY( x, Direction );
  end;

{  Function GetKeyValue1( const x: Double ): Integer;
  begin
    with EP[ indx-1 ].xDep do
      Result := Trunc( Items[ cTb_KeyValue1 ].EstimateY( x, Direction ) );
  end;

  ###

  Function GetParFromShell1( const x: Double ): Double;
  begin
    with EP[ indx-1 ].xDep do
      Result := Items[ cTb_ParFromShell1 ].EstimateY( x, Direction );
  end;

  ###}

// Function GetDefaultPar1( const KeyValue1: Integer ): Double;
// begin
//    with EP[ cEP0 ].xInDep.Items[ cTb_DefaultPar1 ] do
//      Result := GetValue( 1, KeyValue1 );} {row, column}
// end;

{  Function GetDefaultPar2( const KeyValue1, KeyValue2: Integer ): Double;
  begin
    with EP[ cEP0 ].xInDep.Items[ cTb_DefaultPar2 ] do
      Result := GetValue( KeyValue1, KeyValue2 );} {row, column}
{  end;

  ###}

  {- User defined functions/procedures to calculate CalcPar1, CalcPar2... etc.}

  {###}

begin {-Function SetKeyAndParValues}
  Result            := False;
  IErr              := cUnknownError;
  NatschadePerc     := cNoResult;
  DroogteschadePerc := cNoResult;
  TotaleSchadePerc  := cNoResult;

  Gewas := GetKeyValue_Gewas( x );
  if ( Gewas < cMin_KeyValue_Gewas ) or ( Gewas > cMax_KeyValue_Gewas ) then begin
    IErr := cInvld_ParFromShell_Gewas; Exit;
  end;
  Bodemtype := GetKeyValue_Bodemtype( x );
  if ( Bodemtype < cMin_KeyValue_Bodemtype ) or ( Bodemtype > cMax_KeyValue_Bodemtype ) then begin
    IErr := cInvld_ParFromShell_Bodemtype; Exit;
  end;

  GHG := GetParFromShell_GHG( x );
  if ( GHG < cMin_ParValueGHG ) or ( GHG > cMax_ParValueGHG ) then begin
    IErr := cInvld_ParFromShell_GHG; Exit;
  end;
  GLG := GetParFromShell_GLG( x );
  if ( GLG < cMin_ParValueGLG ) or ( GLG > cMax_ParValueGLG ) then begin
    IErr := cInvld_ParFromShell_GLG; Exit;
  end;

  {DefaultPar1 := GetDefaultPar1( KeyValue1 );
  if ( DefaultPar1 < cMin_ParValue1 ) or ( DefaultPar1 > cMax_ParValue1 ) then begin
    IErr := cInvld_DefaultPar1; Exit;
  end;

  ###

  DefaultPar2 := GetDefaultPar2( KeyValue1, KeyValue2 );
  if ( DefaultPar2 < cMinParValue2 ) or ( DefaultPar2 > cMaxParValue2 ) then begin
    IErr := cInvld_DefaultPar2; Exit;
  end;

  ###

  CalcPar1 := ###
  if (CalcPar1 < cMinCalcPar) or ###}

  GLG := GLG * 100; {-Ga over op cm-mv}
  GHG := GHG * 100;

  {-Kuis GLG & GHG tbv opzoeken nat- en droogteschade in tabellen}
  if (( GHG < 200) and (GLG <= (1.15 * GHG + 24))) then begin
    IErr := cInvld_ParFromShell_GxG_combi_DomainA; Exit;
  end else if (( GHG >= 200) and (GLG < 250)) then begin
    IErr := cInvld_ParFromShell_GxG_combi_DomainB; Exit;
  end else if (( GHG <= 90) and (GLG > 250) and (GLG <= 320) and
               (GLG >= (0.78 * GHG + 250) )) then begin
    IErr := cInvld_ParFromShell_GxG_combi_DomainD; Exit;
  end else if ( ( GHG <= 90) and (GLG > 320)) then begin
    IErr := cInvld_ParFromShell_GxG_combi_DomainE; Exit;
  end else if ((GHG >= 200) AND (GLG > 250) AND (GLG <= 320)) then {-Domein c}
    GHG := 200
  else if ((GHG > 90) AND (GHG <= 200) AND (GLG > 320)) then {-Domein f}
    GLG := 320
  else if  ( (GHG > 200) AND (GLG > 320)) then begin {-Domein g}
    GLG := 320;
    GHG := 200;
  end else; {-Binnen gearceerde domein: GxG's ongewijzigd}

  iTableNat    := cTb_MinMaxValKeys +
                  ( Gewas - 1 ) * Trunc( cMax_KeyValue_Bodemtype ) * 2 +
                  ( BodemType - 1 ) * 2 + 1;
  iTableDroog  :=  iTableNat + 1;

  with EP[ cEP0 ].xInDep.Items[ iTableNat ] do begin
    NRows := GetNRows;
    NCols := GetNCols;
    iRow := max( min( NRows - Trunc( GLG ), NRows ), 1 );
    iCol := max( min( Trunc( GHG ), NCols ), 1 );
    NatschadePerc := GetValue( iRow, iCol );
  end;

  DroogteschadePerc := EP[ cEP0 ].xInDep.Items[ iTableDroog ].GetValue( iRow, iCol );

  if ( ( NatschadePerc < 0 ) or( DroogteschadePerc < 0 ) ) then begin
    IErr := cInvld_ParFromShell_GxG_combi; Exit;
  end;

  TotaleSchadePerc := ( 1 - ( (100-NatschadePerc)/100 )* ( (100-DroogteschadePerc)/100) ) * 100;

  Result := True; IErr := cNoError;
end; {-Function SetKeyAndParValues}

Function Replace_InitialValues_With_ShellValues( var IErr: Integer): Boolean;
  {-Als de Shell 1-of meer initiele waarden aanlevert voor de array met afhankelijke
    variabelen ('y'), dan kunnen deze waarden hier op deze array worden geplaatst en
    gecontroleerd}
begin
    IErr := cNoError; Result := True;
//  with EP[ indx-1 ].xDep do
//    y[ ### ] := Items[ cTB_### ].EstimateY( 0, Direction ); {Opm.: x=0}
//  if ( y[ ### ] < cMin_InitVal1 ) or
//     ( y[ ### ] > cMax_InitVal1 ) then begin
//    IErr := cInvld_Init_Val1; Result := False; Exit;
//  end;
end; {-Replace_InitialValues_With_ShellValues}


begin {-Procedure DerivsProc}
  for i := 1 to cNrOfDepVar do
    dydx[ i ] := 0;

  IErr := cUnknownError;

  {-Geef de aanroepende procedure een handvat naar het ModelProfiel}
  if ( nDC > 0 ) then
    aModelProfile := @ModelProfile
  else
    aModelProfile := NIL;

  if not SetKeyAndParValues( IErr ) then
    exit;

  if ( Context = UpdateYstart ) then begin {-Run fase 1}

    {-Fill globally defined parameters from EP[0]}
    if not SetParValuesFromEP0( IErr ) then Exit;

    {-Optioneel: initiele waarden vervangen door Shell-waarden}
//    if not Replace_InitialValues_With_ShellValues( IErr ) then
//	  Exit;

    {-Bij Shell-gebruik van het model (indx = cBoot2) dan kan het wenselijk zijn de tijd-as
	  van alle Shell-gegevens te converteren, bijvoorbeeld naar jaren}
//      ### if ( indx = cBoot2 ) then
//        ScaleTimesFromShell( cFromDayToYear, EP ); ###
    IErr := cNoError;

  end else begin {-Run fase 2}

    {-Bereken de array met afgeleiden 'dydx'.
	  Gebruik hierbij 'DCfunc' van 'ModelProfile' i.p.v.
	  'if'-statements! Als hierbij de 'AsSoonAs'-optie
	  wordt gebruikt, moet de statement worden aangevuld
	  met een extra conditie ( Context = Trigger ). Dus
	  bijv.: if DCfunc( AsSoonAs, h, LE, BodemNiveau, Context, cDCfunc0 )
	     and ( Context = Trigger ) then begin...}
    dydx[ cy1 ] := NatschadePerc;
    dydx[ cy2 ] := DroogteschadePerc;
    dydx[ cy3 ] := TotaleSchadePerc;

  end;
end; {-DerivsProc}

Function DefaultBootEP( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-Initialiseer de meest elementaire gegevens van het model. Shell-gegevens worden door deze
    procedure NIET verwerkt}
Procedure SetMinMaxKeyAndParValues;
begin
  with EP[ cEP0 ].xInDep.Items[ cTb_MinMaxValKeys ] do begin
    cMin_KeyValue_Gewas := Trunc( GetValue( 1, 1 ) ); {rij, kolom}
    cMax_KeyValue_Gewas := Trunc( GetValue( 1, 2 ) );
    cMin_KeyValue_Bodemtype   := Trunc( GetValue( 1, 3 ) );
    cMax_KeyValue_Bodemtype   := Trunc( GetValue( 1, 4 ) );
    cMin_ParValueGHG :=                 GetValue( 1, 5 );
    cMax_ParValueGHG :=                 GetValue( 1, 6 );
    cMin_ParValueGLG :=                 GetValue( 1, 7 );
    cMax_ParValueGLG :=                 GetValue( 1, 8 );
  end;

end;
Begin
  Result := DefaultBootEPFromTextFile( EpDir, BootEpArrayOption, cModelID, cNrOfDepVar, nDC, cNrXIndepTblsInEP0,
                                       cNrXdepTblsInEP0, Indx, EP );
  if ( Result = cNoError ) then begin
    SetMinMaxKeyAndParValues;
    {###SetAnalytic_DerivsProc( True, EP );} {-Ref. 'USpeedProc.pas'}
  end;
end;

Function TestBootEP( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-Deze boot-procedure verwerkt alle basisgegevens van het model en leest de Shell-gegevens
    uit een bestand. Na initialisatie met deze boot-procedure is het model dus gereed om
	'te draaien'. Deze procedure kan dus worden gebruikt om het model 'los' van de Shell te
	testen}
Begin
  Result := DefaultBootEP( EpDir, BootEpArrayOption, EP );
  if ( Result <> cNoError ) then
    exit;
  Result := DefaultTestBootEPFromTextFile( EpDir, BootEpArrayOption, cModelID, cnRP + cnSQ + cnRQ, Indx, EP );
  if ( Result <> cNoError ) then
    exit;
  SetReadyToRun( EP);
end;

Function BootEPForShell( const EpDir: String; const BootEpArrayOption: TBootEpArrayOption; var EP: TExtParArray ): Integer;
  {-Deze procedure maakt het model gereed voor Shell-gebruik.
    De xDep-tables in EP[ indx-1 ] worden door deze procedure NIET geinitialiseerd omdat deze
	gegevens door de Shell worden verschaft }
begin
  Result := DefaultBootEP( EpDir, cBootEPFromTextFile, EP );
  if ( Result = cNoError ) then
    Result := DefaultBootEPForShell( cnRP, cnSQ, cnRQ, Indx, EP );
end;

Exports DerivsProc       index cModelIndxForTDSmodels, {999}
        DefaultBootEP    index cBoot0, {1}
        TestBootEP       index cBoot1, {2}
        BootEPForShell   index cBoot2; {3}

begin
  {-Dit zgn. 'DLL-Main-block' wordt uitgevoerd als de DLL voor het eerst in het geheugen wordt
    gezet (Reason = DLL_PROCESS_ATTACH)}
  DLLProc := @MyDllProc;
  Indx := cBootEPArrayVariantIndexUnknown;
  if ( nDC > 0 ) then
    ModelProfile := TModelProfile.Create( nDC );
end.

