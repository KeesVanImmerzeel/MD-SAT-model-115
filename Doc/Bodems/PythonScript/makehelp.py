# Maak op basis van de bodemkaart info in het bestand 'table1.txt'
#    met daarin de kolommen "Objectid", "Code"
# een bestand 'helpids.txt' met daarin de kolommen:
#    wr.writerow(["Objectid", "HELP_CODE","CODE","HELPID", \
#      "BFeenh","bfe","Fit","Strng_B","Textuur","Walrus"])
# Het uitvoerbestand kan via het veld "Objectid" worden gelinked aan
# de bodemkaart.
# De basisinformatie voor 'helpids.txt' staat in de spreadsheet:
# 'D:\Documents\Embarcadero\Studio\Projects\Applicaties\MD-SAT\Source\DSmodelS\Models\Dsmodel115\Doc\Bodems\bod2helpid.xlsx'
# Vervolgens wordt de beste match gezocht in de tabel met bodemfysiche eenheden ''BOFEK2012_profielen.csv''
# Samen met de staring reeks in 'MVG_per bouwsteen Staringreeks_hlp.csv'



import csv
import difflib
from difflib import SequenceMatcher
import re

# Lees de geexporteerde tabel van de bodemkaart (='table1.txt') --> 'soils_list'
with open('table1.txt') as soilsfile:
  soils_reader = csv.DictReader(soilsfile)
  soils_list = list( soils_reader )
  print 'table1.txt gelezen.'
  #for row in soils_list:
    #print row['Objectid'],row['Code']

# Lees de tabel waarin voor ieder denkbaar bodemtype (veld 'BODEM')
# de HELPID is opgenomen(veld 'HELPID')
# en de HELP_CODE (veld 'HELP_CODE') --> soilcode_list
with open('bod2helpid.csv') as soilcodefile:
  soilcode_reader = csv.DictReader(soilcodefile)
  soilcode_list = list( soilcode_reader )
  print 'bod2helpid.csv gelezen.'

# Lees tabel met bodemfysiche eenheden (='BOFEK2012_profielen.csv') --> BOFEK2012_list
with open('BOFEK2012_profielen.csv') as BOFEK2012file:
  BOFEK2012_reader = csv.DictReader( BOFEK2012file )
  BOFEK2012_list = list( BOFEK2012_reader )
  print 'BOFEK2012 tabel gelezen.'

# Lees tabel met de Staring reeksen
with open('MVG_per bouwsteen Staringreeks_hlp.csv') as staringFile:
  staring_reader = csv.DictReader( staringFile )
  staring_list = list(staring_reader)

with open('gwt.csv') as gwtfile:
  gwt_reader = csv.DictReader( gwtfile )
  gwt_list = list(gwt_reader)
#for row in gwt_list:
#  print row


# Zoek bij ieder record in de bodemkaart de bijbehorende gegevens in
# 'soilcode_list' --> list helpids()
helpids=list()
for rowsr in soils_list:
  helpid=0
  help_code=''
  gt_code = 0
  ghg = -999
  glg = -999
  objectid = rowsr['Objectid']
  code = rowsr['Code'].split('-')[0]
  if code[0] == 'U':
      code = rowsr['Omschr'].split('-')[0]
  eerste_gwt = rowsr['Eerste_gwt'].strip()
  gwt = rowsr['Gwt'].strip()
  #print eerste_gwt, gwt

  # Zoek de HELPID en HELPCODE
  for rowsc in soilcode_list:
    bodem=rowsc['BODEM']
    if code == bodem: #HELPID gevonden in soilcode_list
      helpid=rowsc['HELPID']
      help_code=rowsc['HELP_CODE']
      break

  #Zoek de gt_code, ghg en glg
  #print objectid, eerste_gwt
  for row in gwt_list:
    eerstegwt = row['Eerste_gwt']
    eerstegwt = eerstegwt.strip()
    #print eerste_gwt, eerstegwt
    if eerste_gwt == eerstegwt:
      #print "gelijk"
      gt_code = int(row['Gt-code'])
      ghg = float(row['GHG'])
      glg = float(row['GLG'])
      break
  if gt_code == 0 and code == '|h BEBOUW':
    #print "gevonden..."
    for row2 in gwt_list:
      eerstegwt = row2['Eerste_gwt'].strip()
      if eerstegwt == 'VI':
        #print "... en vervangen"
        gt_code = int(row['Gt-code'])
        ghg = float(row['GHG'])
        glg = float(row['GLG'])
        break

  # Zoek de beste match in de tabel met bodemfysiche eenheden BOFEC2012_list
  bfeenheid_used = ''
  bfe = 0
  m_max = 0 #Indicatie van de mate van match: 0=geen match; 1=volledige match
  Strng_B = '' #Staring bouwsteen bovengrond
  Textuur='' #Staring textuur
  Walrus=0   #Walruscode op basis van bovengrond staringreeks

  for rowbf in BOFEK2012_list:
    bfeenheid = rowbf['Eenheid']
    m = SequenceMatcher(None, code, bfeenheid)
    res = m.ratio()
    if res > m_max:
      m_max = res
      bfeenheid_used = bfeenheid
      bfe=int(rowbf['Bodem-nr'])
      Strng_B = rowbf['Staring bouwsteen']

      #Zoek de Staringreeks info erbij
      for rowst in staring_list:
        if Strng_B == rowst['StrngCode']:
          Textuur=rowst['Textuur']
          Textuur = re.sub('[,]', '', Textuur) #Verwijder evt. komma's
          Walrus=int(rowst['Walrus'])
          break
  if m_max < 0.4:
    bfeenheid_used = 'Onbekend'
    bfe = 0

  helpids.append( (int(objectid),help_code, code,int(helpid), \
    bfeenheid_used, bfe, m_max, Strng_B, Textuur, Walrus, \
    gt_code, ghg, glg ) )


#Schrijf het resultaat (list helpids()) weg in het bestand 'helpids.txt'
with open('helpids.txt', 'wb') as myfile:
    wr = csv.writer(myfile, quoting=csv.QUOTE_NONNUMERIC)
    wr.writerow(["Objectid", "HELP_CODE","CODE","HELPID", \
      "BFeenh","bfe","Fit","Strng_B","Textuur","Walrus", \
      "Gt_code", "GHG", "GLG"])
    for i in range(0, len(helpids)-1 ):
      item = helpids[i]
      wr.writerow(item)
