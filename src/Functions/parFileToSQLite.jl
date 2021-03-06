# This file holds the functions used to read an Excel parameter file and store
#   the configuration in a SQLite table.

export readParFileToDatabase


"""
```
readParFileToDatabase( fileName::String,
                       dbName::String,
                       configName::String = "config" )
```
This function reads the Excel file with filename `fileName`, processes the
parameters, and stores them in the `config` of the SQLite database with filename
`dbName`. If these filenames do not have the proper extension, `.xlsx` for the
Excel and `.sqlite` for the database, it will be apended to the name.

This function returns `nothing`. If the Excel file doesn't exist, this function
will throw an error.
"""
function readParFileToDatabase( fileName::String, dbName::String,
    configName::String = "config" )::Void

    newMPsim = ManpowerSimulation( fileName )
    saveSimConfigToDatabase( mpSim, dbName, configName )
#=    tmpFileName = fileName * ( endswith( fileName, ".xlsx" ) ? "" : ".xlsx" )

    if !isfile( tmpFileName )
        error( "File '$tmpFileName' does not exist." )
    end  # if !isfile( tmpFileName )

    # Read and validate the parameter file.
    wb = Workbook( tmpFileName )

    if !validateParFile( wb )
        warn( "Improperly formatted Excel parameter file. Can't export simulation configuration to SQLite." )
    end  # if !validateParFile( wb )

    tmpDBname = ( dbName == "" ) || endswith( dbName, ".sqlite" ) ? dbName :
        dbName * ".sqlite"
    configDB = SQLite.DB( tmpDBname )

    createConfigTable( configName, configDB )

    command = "BEGIN TRANSACTION"
    SQLite.execute!( configDB, command )

    readGeneralParsFromFile( wb, configDB, configName )
    readAttributesFromFile( wb, configDB, configName )
    readStatesFromFile( wb, configDB, configName )
    readTransitionsFromFile( wb, configDB, configName )
    readRecruitmentFromFile( wb, configDB, configName )
    readAttritionFromFile( wb, configDB, configName )
    readRetirementFromFile( wb, configDB, configName )

    command = "COMMIT"
    SQLite.execute!( configDB, command )=#

    return

end  # readParFileToDatabase( fileName, dbName )


# ==============================================================================
# Non-exported methods.
# ==============================================================================

"""
```

```
This function creates a table with name `configName` in the SQLite database
`configDB` to store the simulation configuration parameters in the SQLite
database `configDB`.

This function returns `nothing`.
"""
function createConfigTable( configName::String, configDB::SQLite.DB )::Void

    SQLite.drop!( configDB, configName, ifexists = true )
    command = "CREATE TABLE $configName(
        parName VARCHAR( 32 ),
        parType VARCHAR( 32 ),
        intPar MEDIUMINT,
        realPar FLOAT,
        boolPar VARCHAR( 5 ),
        strPar TEXT
    )"
    SQLite.execute!( configDB, command )

    return

end

#=
"""
```
validateParFile( wb::Workbook )
```
This function tests of the Excel workbook `wb` has the correct sheets in it and
returns the result.

This function returns a `Bool`.
"""
function validateParFile( wb::Workbook )::Bool

    sheetNames = [ "General",
                   "Attributes",
                   "States",
                   "Transitions",
                   "Recruitment",
                   "Attrition",
                   "Retirement" ]
    return !any( shName -> getSheet( wb, shName ).ptr === Ptr{Void}( 0 ),
        sheetNames )

end  # validateParFile( wb )


"""
```
readGeneralParsFromFile( wb::Workbook,
                         configDB::SQLite.DB,
                         configName::String )
```
This function reads the general simulation parameters from the Excel workbook
`wb` and writes them to the SQLite database `configDB` in the table
`configName`.

This function returns `nothing`.
"""
function readGeneralParsFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "General" )

    # Name of the simulation database file.
    dbName = sheet[ "B", 3 ]
    dbName = dbName === nothing ? "" : string( dbName )
    dbName *= ( dbName == "" ) || endswith( dbName, ".sqlite" ) ? "" : ".sqlite"
    command = "INSERT INTO $configName
        (parName, parType, strPar) VALUES
        ('dbName', 'General', '$dbName')"
    SQLite.execute!( configDB, command )

    # Name of the simulation.
    simName = sheet[ "B", 4 ]
    simName = simName === nothing ? "" : string( simName )
    command = "INSERT INTO $configName
        (parName, parType, strPar) VALUES
        ('simName', 'General', '$simName')"
    SQLite.execute!( configDB, command )

    # Personnel cap.
    command = "INSERT INTO $configName
        (parName, parType, intPar) VALUES
        ('persCap', 'General', '$(sheet[ "B", 5 ])')"
    SQLite.execute!( configDB, command )

    # Simulation length.
    command = "INSERT INTO $configName
        (parName, parType, realPar) VALUES
        ('simLength', 'General', '$(sheet[ "B", 7 ])')"
    SQLite.execute!( configDB, command )

    # Database commits.
    command = "INSERT INTO $configName
        (parName, parType, intPar) VALUES
        ('dbCommits', 'General', '$(sheet[ "B", 8 ])')"
    SQLite.execute!( configDB, command )

    return

end  # readGeneralParsFromFile( wb, configDB )


"""
```
readAttributesFromFile( wb::Workbook,
                        configDB::SQLite.DB,
                        configName::String )
```
This function reads the personnel attributes from the Excel workbook `wb` and
writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readAttributesFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "Attributes" )
    nAttrs = sheet[ "B", 3 ]
    sLine = 5
    lastLine = numRows( sheet, "C" )
    ii = 1

    # Read every single attribute.
    while ( sLine <= lastLine ) && ( ii <= nAttrs )
        newAttr, sLine = readAttribute( sheet, sLine )
        saveAttrToDatabase( newAttr, configDB, configName )
        ii += 1
    end  # while ( sLine <= lastLine ) && ...

    return

end  # readAttributesFromFile( wb, configDB, configName )


"""
```
saveAttrToDatabase( attr::PersonnelAttribute,
                    configDB::SQLite.DB,
                    configName::String )
```
This function saves the personnel attribute `attr` to the SQLite database
`configDB` in table `configName`.

This function returns `nothing`.
"""
function saveAttrToDatabase( attr::PersonnelAttribute, configDB::SQLite.DB,
    configName::String )::Void

    valueList = join( map( val -> "$val,$(attr.values[ val ])",
        keys( attr.values ) ), ";" )
    command = "INSERT INTO $configName
        (parName, parType, boolPar, strPar) VALUES
        ('$(attr.name)', 'Attribute', '$(attr.isFixed)', '$valueList')"
    SQLite.execute!( configDB, command )

    return

end  # saveAttrToDatabase( attr, configDB, configName )


"""
```
readStatesFromFile( wb::Workbook,
                    configDB::SQLite.DB,
                    configName::String )
```
This function reads the personnel states from the Excel workbook `wb` and
writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readStatesFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "States" )
    nStates = sheet[ "B", 3 ]
    sLine = 5
    lastLine = numRows( sheet, "C" )
    ii = 1

    # Read every single attribute.
    while ( sLine <= lastLine ) && ( ii <= nStates )
        newState, isInitial, attrName, sLine = readState( sheet, sLine )
        saveStateToDatabase( newState, attrName, configDB, configName )
        ii += 1
    end  # while ( sLine <= lastLine ) && ...

    return

end  # readStatesFromFile( wb, configDB, configName )


"""
```
saveStateToDatabase( state::State,
                     attrName::String,
                     configDB::SQLite.DB,
                     configName::String )
```
This function saves the personnel state `state` with associated attrition scheme
with name `attrName` to the SQLite database `configDB` in table `configName`.

This function returns `nothing`.
"""
function saveStateToDatabase( state::State, attrName::String,
    configDB::SQLite.DB, configName::String )::Void

    valueList = Vector{String}()

    for attr in keys( state.requirements )
        stateReq = "$attr:"
        vals = state.requirements[ attr ]
        stateReq *= length( vals ) == 1 ? vals[ 1 ] :
            "[" * join( vals, "/" ) * "]"
        push!( valueList, stateReq )
    end  # for attr in keys( state.requirements )

    command = "INSERT INTO $configName
        (parName, parType, intPar, boolPar, strPar) VALUES
        ('$(state.name)', 'State', $(state.stateTarget), '$(state.isInitial)',
            '$attrName;[$(join( valueList, "," ))]')"
    SQLite.execute!( configDB, command )

    return

end  # saveStateToDatabase( state, attrName, configDB, configName )


"""
```
readTransitionsFromFile( wb::Workbook,
                         configDB::SQLite.DB,
                         configName::String )
```
This function reads the state transitions from the Excel workbook `wb` and
writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readTransitionsFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "Transitions" )
    nStates = sheet[ "B", 3 ]
    sLine = 5
    lastLine = numRows( sheet, "C" )
    ii = 1

    # Read every single attribute.
    while ( sLine <= lastLine ) && ( ii <= nStates )
        newState, startName, endName, sLine = readTransition( sheet, sLine )
        saveTransitionToDatabase( newState, startName, endName, configDB,
            configName )
        ii += 1
    end  # while ( sLine <= lastLine ) && ...

    return

end  # readTransitionsFromFile( wb, configDB, configName )


"""
```
saveTransitionToDatabase( trans::Transition,
                          startName::String,
                          endName::String,
                          configDB::SQLite.DB,
                          configName::String )
```
This function saves the state transition `trans`, including `startName` and
`endName` as the names of the start and end states, to the SQLite database
`configDB` in table `configName`.

This function returns `nothing`.
"""
function saveTransitionToDatabase( trans::Transition, startName::String,
    endName::String, configDB::SQLite.DB, configName::String )::Void

    valueList = "$startName;$endName;"
    valueList *= "$(trans.freq);$(trans.offset);$(trans.minTime);["
    extraConds = Vector{String}()

    for cond in trans.extraConditions
        extraCond = "$(cond.attr)|"

        if cond.rel ∈ [ ==, != ]
            extraCond *= "IS" * ( cond.rel == Base.:!= ? " NOT" : "" ) * "|"
        elseif cond.rel ∈ [ ∈, ∉ ]
            extraCond *= ( cond.rel == Base.:∈ ? "" : "NOT " ) * "IN|"
        else
            extraCond *= "$(cond.rel)|"
        end

        extraCond *= isa( cond.val, Vector{String} ) ? join( cond.val, "/" ) :
            "$(cond.val)"
        push!( extraConds, extraCond )
    end  # for cond in trans.extraConditions

    valueList *= "$(join( extraConds, "," ))];["
    extraChanges = Vector{String}()

    for attr in trans.extraChanges
        val = collect( keys( attr.values ) )[ 1 ]
        push!( extraChanges, "$(attr.name):$val" )
    end  # for attr in trans.extraChanges

    valueList *= join( extraChanges, "," )
    valueList *= "];$(trans.maxAttempts);$(trans.maxFlux);"
    valueList *= "[$(join( trans.probabilityList, "," ))]"
    command = "INSERT INTO $configName
        (parName, parType, boolPar, strPar) VALUES
        ('$(trans.name)', 'Transition', '$(trans.isFiredOnFail)', '$valueList')"
    SQLite.execute!( configDB, command )

    return

end  # saveTransitionToDatabase( trans, startName, endName, configDB,
     #     configName )


"""
```
readRecruitmentFromFile( wb::Workbook,
                         configDB::SQLite.DB,
                         configName::String )
```
This function reads the the recruitment schemens from the Excel workbook `wb`
and writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readRecruitmentFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "Recruitment" )
    numSchemes = Int( sheet[ "B", 3 ] )

    for ii in 1:numSchemes
        recScheme = generateRecruitmentScheme( sheet, ii )
        saveRecruitmentToDatabase( recScheme, configDB, configName )
    end  # for ii in 1:numSchemes

    return

end


"""
```
saveRecruitmentToDatabase( recScheme::Recruitment,
                           configDB::SQLite.DB,
                           configName::String )
```
This function saves the recruitment scheme `recScheme` to the SQLite database
`configDB` in table `configName`.

This function returns `nothing`.
"""
function saveRecruitmentToDatabase( recScheme::Recruitment, configDB::SQLite.DB,
    configName::String )::Void

    isAdaptive = recScheme.isAdaptive
    valueList = "$(recScheme.recruitFreq);$(recScheme.recruitOffset);"

    # Recruitment number.
    if isAdaptive
        valueList *= "$(recScheme.minRecruit);$(recScheme.maxRecruit)"
    else
        valueList *= "$(recScheme.recDistType);["
        recDist = recScheme.recDistNodes
        valueList *= join( map( node -> "$node:$(recDist[ node ])",
            keys( recDist ) ), "," )
        valueList *= "]"
    end  # if isAdaptive

    # Recruitment age.
    valueList *= ";$(recScheme.ageDistType);["
    ageDist = recScheme.ageDistNodes
    valueList *= join( map( node -> "$(node):$(ageDist[ node ])",
        keys( ageDist ) ), "," )
    valueList *= "]"

    command = "INSERT INTO $configName
        (parName, parType, boolPar, strPar) VALUES
        ('$(recScheme.name)', 'Recruitment', '$isAdaptive', '$valueList')"
    SQLite.execute!( configDB, command )

    return

end  # saveAttrToDatabase( attr, configDB, configName )


"""
```
readAttritionFromFile( wb::Workbook,
                       configDB::SQLite.DB,
                       configName::String )
```
This function reads the attrition parameters from the Excel workbook `wb` and
writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readAttritionFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "Attrition" )

    # Default attrition scheme.
    attrScheme = readAttrition( sheet, 2, true )
    saveAttritionToDatabase( attrScheme, configDB, configName )
    colNr = 5

    # Read all other attrition schemes.
    while !isa( sheet[ colNr, 5 ], Void )
        attrScheme = readAttrition( sheet, colNr )
        saveAttritionToDatabase( attrScheme, configDB, configName )
        colNr += 3
    end  # while !isa( s[ colNr, 5 ], Void )

    return

end  # readAttritionFromFile( wb, configDB, configName )


"""
```
saveAttritionToDatabase( attrScheme::Attrition,
                         configDB::SQLite.DB,
                         configName::String )
```
This function saves the attrition scheme `attrScheme` tot he SQLite database
`configDB` in table `configName`.

This function returns `nothing`.
"""
function saveAttritionToDatabase( attrScheme::Attrition, configDB::SQLite.DB,
    configName::String )

    # If there's only one rate in the attrition curve, and it's zero, no need to
    #   store anything.
    # if ( length( attrScheme.attrRates ) == 1 ) &&
    #     ( attrScheme.attrRates[ 1 ] == 0 )
    #     return
    # end  # if ( length( attrScheme.attrRates ) == 1 ) && ...

    attrName = attrScheme.name
    attrPeriod = attrScheme.attrPeriod
    attrCurvePoints = attrScheme.attrCurvePoints
    attrCurve = join( map( ii -> "$(attrCurvePoints[ ii ]):$(attrScheme.attrRates[ ii ])",
        eachindex( attrCurvePoints ) ), "," )
    command = "INSERT INTO $configName
        (parName, parType, strPar) VALUES
        ('$attrName', 'Attrition', '$attrPeriod;[$attrCurve]')"
    SQLite.execute!( configDB, command )

    return

end


"""
```
readRetirementFromFile( wb::Workbook,
                        configDB::SQLite.DB,
                        configName::String )
```
This function reads the retirement parameters from the Excel workbook `wb` and
writes them to the SQLite database `configDB` in the table `configName`.

This function returns `nothing`.
"""
function readRetirementFromFile( wb::Workbook, configDB::SQLite.DB,
    configName::String )::Void

    sheet = getSheet( wb, "Retirement" )
    maxTenure = sheet[ "B", 5 ]
    maxAge = sheet[ "B", 6 ]

    # No need to store a retirement scheme if there's no retirement age or max
    #   tenure.
    if ( maxTenure == 0 ) && ( maxAge == 0 )
        return
    end  # if ( maxTenure == 0 ) && ...

    isEither = sheet[ "B", 7 ] == "EITHER"

    command = "INSERT INTO $configName
        (parName, parType, boolPar, strPar) VALUES
        ('Retirement', 'Retirement', '$isEither',
            '$maxTenure,$maxAge,$(sheet[ "B", 3 ]),$(sheet[ "B", 4 ])')"
    SQLite.execute!( configDB, command )

    return

end  # readRetirementFromFile( wb, configDB, configName )
=#
