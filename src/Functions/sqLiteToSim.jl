# This file holds the functions to configure a manpower simulation from an
#   SQLite configuration database.

export configureSimFromDatabase


"""
```
configureSimFromDatabase( mpSim::ManpowerSimulation,
                          dbName::String,
                          configName::String = "config" )
```
This function configures the manpower simulation `mpSim` form the configuration
table with name `configName` in the SQLite database with filename `dbName`. If
the database is missing the appropriate extension, `.sqlite`, it will be
appended to the name.

The function returns `nothing`. If the database doesn't exist, or doesn't
contain a proper configuration, the function will throw an error.
"""
function configureSimFromDatabase( mpSim::ManpowerSimulation, dbName::String,
    configName::String = "config" )::Void

    tmpDBname = dbName * ( endswith( dbName, ".sqlite" ) ? "" : ".sqlite" )

    # Check if the file exists.
    if !ispath( tmpDBname )
        error( "File '$tmpDBname' does not exist." )
    end  # if !ispath( tmpDBname )

    configDB = SQLite.DB( tmpDBname )

    # check if a configuration table exists.
    if configName ∉ SQLite.tables( configDB )[ :name ]
        error( "Database `$tmpDBname` does not contain a manpower simulation configuration." )
    end  # if configName ∉ SQLite.tables( configDB )[ :name ]

    # Get the general parameters
    readGeneralParsFromDatabase( configDB, mpSim, configName )
    readAttributesFromDatabase( configDB, mpSim, configName )
    readRecruitmentFromDatabase( configDB, mpSim, configName )
    readAttritionFromDatabase( configDB, mpSim, configName )
    readRetirementFromDatabase( configDB, mpSim, configName )

    return

end  # configureSimFromDatabase( mpSim, dbName )


# ==============================================================================
# Non-exported methods.
# ==============================================================================


"""
```
readGeneralParsFromDatabase( configDB::SQLite.DB,
                             mpSim::ManpowerSimulation,
                             configName::String )
```
This function reads the general simulation parameters from the SQLite database
`configDB`, looking in the table with name `configName`, and uses these
parameters to configure the manpower simulation `mpSim`.

This function returns `nothing`. If information is missing, the funuction will
issue warnings, or throw an error depending on the severity.
"""
function readGeneralParsFromDatabase( configDB::SQLite.DB,
    mpSim::ManpowerSimulation, configName::String )::Void

    queryCmd = "SELECT * FROM $configName
        WHERE parType IS 'General'"
    generalPars = SQLite.query( configDB, queryCmd )

    # Database name.
    index = findfirst( generalPars[ :parName ], "dbName" )

    # Complain if the info isn't there and set it to a default value.
    if index == 0
        warn( "No database name found in the configuration table. Using default name `simDB.sqlite`" )
        mpSim.dbName = "simDB.sqlite"
    else
        dbName = generalPars[ :strPar1 ][ index ]

        if !isa( dbName, String )
            warn( "No database name found in the configuration table. Using default name `simDB.sqlite`" )
            dbName = "simDB.sqlite"
        end  # if !isa( dbName, String )

        mpSim.dbName = dbName
    end  # if index == 0

    mpSim.simDB = SQLite.DB( mpSim.dbName )

    # This line ensures that foreign key logic works.
    SQLite.execute!( mpSim.simDB, "PRAGMA foreign_keys = ON" )

    # Simulation name.
    index = findfirst( generalPars[ :parName ], "simName" )

    # Complain if the info isn't there and set it to a default value.
    if index == 0
        warn( "No simulation name found in the configuration table. Using default name `testSim`" )
        simName = "testSim"
    else
        simName = generalPars[ :strPar1 ][ index ]

        if !isa( dbName, String )
            warn( "No simulation name found in the configuration table. Using default name `testSim`" )
            simName = "testSim"
        end  # if !isa( dbName, String )
    end  # if index == 0

    mpSim.personnelDBname = "Personnel_" * simName
    mpSim.historyDBname = "History_" * simName

    # Personnel cap.
    index = findfirst( generalPars[ :parName ], "persCap" )

    # Complain if the info isn't there and set it to a default value.
    if index == 0
        warn( "No personnel cap info found in the configuration table. Using default value of 0 (no cap)." )
        setPersonnelCap( mpSim, 0 )
    else
        setPersonnelCap( mpSim, generalPars[ :intPar1 ][ index ] )
    end  # if index == 0

    # Sim length.
    index = findfirst( generalPars[ :parName ], "simLength" )

    # Complain if the info isn't there and throw an error.
    if index == 0
        error( "No simulation length found in the configuration table. Cannot continue." )
    else
        setSimulationLength( mpSim, generalPars[ :realPar1 ][ index ] * 12 )
    end  # if index == 0

    # Number of DB commits.
    index = findfirst( generalPars[ :parName ], "dbCommits" )

    # Complain if the info isn't there and set it to a default value.
    if index == 0
        warn( "No database commits info found in the configuration table. Using default value of 5." )
        setDatabaseCommitTime( mpSim, mpSim.simLength / 5 )
    else
        setDatabaseCommitTime( mpSim, mpSim.simLength /
            generalPars[ :intPar1 ][ index ] )
    end  # if index == 0

    return

end  # readGeneralParsFromDatabase( configDB, mpSim, configName )


"""
```
readAttributesFromDatabase( configDB::SQLite.DB,
                            mpSim::ManpowerSimulation,
                            configName::String )
```
This function reads the personnel attributes from the SQLite database
`configDB`, looking in the table with name `configName`, and uses these
parameters to configure the manpower simulation `mpSim`.

This function returns `nothing`. If information is missing, the funuction will
issue warnings, or throw an error depending on the severity.
"""
function readAttributesFromDatabase( configDB::SQLite.DB,
    mpSim::ManpowerSimulation, configName::String )::Void

    clearAttributes!( mpSim )
    queryCmd = "SELECT * FROM $configName
        WHERE parType IS 'Attribute'"
    attributes = SQLite.query( configDB, queryCmd )
    nAttrs = length( attributes[ :parName ] )

    for ii in 1:nAttrs
        # Check if the isFixed attribute can be read properly.
        isFixed = attributes[ :boolPar1 ][ ii ]
        isFixed = isa( isFixed, String ) ?
            tryparse( Bool, attributes[ :boolPar1 ][ ii ] ) : Nullable{Bool}()

        if !isFixed.hasvalue
            error( "Can't determine if the attribute is fixed or not." )
        end  # if !isFixed.hasvalue

        # Check if the values can be read properly.
        valList = attributes[ :strPar1 ][ ii ]

        # Value list can't be missing.
        if !isa( valList, String )
            error( "Can't read the values of the attribute." )
        end  # if !isa( valList, String )

        valList = valList == "" ? Vector{String}() : split( valList, ";" )
        values = Dict{String,Float64}()

        for val in valList
            valProbPair = split( val, "," )

            # Value list must consist of value, probability pairs.
            if length( valProbPair ) != 2
                error( "Can't read the values of the attribute." )
            end  # if length( valProbPair ) != 2

            prob = tryparse( Float64, valProbPair[ 2 ] )

            if !prob.hasvalue
                error( "Can't read the values of the attribute." )
            end  # if !prob.hasvalue

            values[ valProbPair[ 1 ] ] = prob.value
        end  # for ii in eachindex( valList )

        newAttr = PersonnelAttribute( attributes[ :parName ][ ii ],
            isFixed.value )

        if !isempty( values )
            setAttrValues!( newAttr, values )
        end  # if !isempty( values )

        addAttribute!( mpSim, newAttr )
    end  # for ii in 1:nAttrs

    return

end  # readAttributesFromDatabase( configDB, mpSim, configName )



"""
```
readRecruitmentFromDatabase( configDB::SQLite.DB,
                             mpSim::ManpowerSimulation,
                             configName::String )
```
This function reads the recruitment schemes from the SQLite database
`configDB`, looking in the table with name `configName`, and uses these
parameters to configure the manpower simulation `mpSim`.

This function returns `nothing`. If information is missing, the funuction will
issue warnings, or throw an error depending on the severity.
"""
function readRecruitmentFromDatabase( configDB::SQLite.DB,
    mpSim::ManpowerSimulation, configName::String )::Void

    clearRecruitmentSchemes!( mpSim )
    queryCmd = "SELECT parName, boolPar1, strPar1 FROM $configName
        WHERE parType IS 'Recruitment'"
    recruitment = SQLite.query( configDB, queryCmd )
    numSchemes = length( recruitment[ :parName ] )

    # If no recruitment schemes are in the database, do nothing.
    if numSchemes == 0
        return
    end  # if numSchemes == 0

    numSchemes = size( recruitment )[ 1 ]

    for ii in 1:numSchemes
        schemePars = recruitment[ ii, : ]
        recScheme = createRecruitmentScheme( schemePars )

        if isa( recScheme, Recruitment )
            addRecruitmentScheme!( mpSim, recScheme )
        end  # if isa( recScheme, Recruitment )
    end  # for ii in 1:numSchemes

    return

end  # readRecruitmentFromDatabase( configDB, mpSim, configName )


"""
```
createRecruitmentScheme( pars::DataFrames.DataFrame )
```
This function processes a line of recruitment information from the database, and
transforms it into a recruitment scheme.

This function returns a `Recruitment` object. If there is a problem processing
the parameters, the function will issue a warning and return `nothing`.
"""
function createRecruitmentScheme( pars::DataFrames.DataFrame )

    name = pars[ :parName ][ 1 ]
    isAdaptive = pars[ :boolPar1 ][ 1 ]
    isAdaptive = isa( isAdaptive, String ) ? tryparse( Bool, isAdaptive ) :
        Nullable{Bool}()
    schemePars = pars[ :strPar1 ][ 1 ]

    # Check if the second parameter can parse as a boolean.
    if !isAdaptive.hasvalue
        warn( "Can't determine if the recruitment scheme is adaptive. Not building recruitment scheme." )
        return
    end  # if !tryparse( Bool, isAdaptive )

    schemePars = split( schemePars, ";" )

    # Check if the correct number of parameters have been defined.
    if length( schemePars ) != 6
        warn( "Recruitment scheme parameters improperly defined. Not building recruitment scheme.." )
        return
    end  # if length( schemePars ) != 6

    # Extract the frequency and the offset of the recruitment scheme.
    freq = tryparse( Float64, schemePars[ 1 ] )
    offset = tryparse( Float64, schemePars[ 2 ] )

    # Check if these parse as numbers.
    if !freq.hasvalue || !offset.hasvalue
        warn( "Cannot process the schedule parameters of the recruitment scheme. Not building recruitment scheme." )
        return
    end  # if !freq.hasvalue || ...

    recScheme = Recruitment( name, freq.value, offset.value )
    distTypes = [ :disc, :pUnif, :pLin ]

    # Extract the recruitment capacity parameters
    if isAdaptive.value
        minRec = tryparse( Float64, schemePars[ 3 ] )
        maxRec = tryparse( Float64, schemePars[ 4 ] )

        # Check recruitment limits.
        if !minRec.hasvalue || !maxRec.hasvalue || ( maxRec.value <= 0 ) ||
            ( maxRec.value < minRec.value )
            warn( "Cannot process recruitment capacity parameters. Not building recruitment scheme." )
            return
        end  # if !minRec.hasvalue ||

        setRecruitmentLimits( recScheme, minRec.value, maxRec.value )
    else
        distType = Symbol( schemePars[ 3 ] )
        # Check recruitment parameters.
        if ( distType ∉ distTypes ) || !startswith( schemePars[ 4 ], "[" ) ||
            !endswith( schemePars[ 4 ], "]" )
            warn( "Cannot process recruitment capacity parameters. Not building recruitment scheme." )
            return
        end  # if ( distType ∉ distTypes ) || ...

        # Build distribution nodes.
        recDistOrig = split( schemePars[ 4 ][ 2:(end-1) ], "," )
        numNodes = length( recDistOrig )
        recDist = Dict{Int, Float64}()

        for ii in 1:numNodes
            node = split( recDistOrig[ ii ], ":" )

            # Check distribution node.
            if length( node ) != 2
                warn( "Cannot process recruitment capacity parameters. Not building recruitment scheme." )
                return
            end  # if length( node ) != 2

            weight = tryparse( Float64, node[ 2 ] )
            node = tryparse( Float64, node[ 1 ] )

            if !node.hasvalue || !weight.hasvalue
                warn( "Cannot process recruitment capacity parameters. Not building recruitment scheme." )
                return
            end   # if !node.hasvalue || ...

            recDist[ Int( node.value ) ] = weight.value
        end  # for ii in 1:numNodes

        setRecruitmentDistribution( recScheme, recDist, distType )
    end  # if isAdaptive

    distType = Symbol( schemePars[ 5 ] )

    # Check recruitment age parameters.
    if ( distType ∉ distTypes ) || !startswith( schemePars[ 6 ], "[" ) ||
        !endswith( schemePars[ 6 ], "]" )
        warn( "Cannot process recruitment age parameters. Not building recruitment scheme." )
        return
    end  # if !haskey( distTypes, schemePars[ 5 ] ) || ...

    # Build distribution nodes.
    ageDistOrig = split( schemePars[ 6 ][ 2:(end-1) ], "," )
    numNodes = length( ageDistOrig )
    ageDist = Dict{Float64, Float64}()

    for ii in 1:numNodes
        node = split( ageDistOrig[ ii ], ":" )

        # Check distribution node.
        if length( node ) != 2
            warn( "Cannot process recruitment age parameters. Not building recruitment scheme." )
            return
        end  # if length( node ) != 2

        weight = tryparse( Float64, node[ 2 ] )
        node = tryparse( Float64, node[ 1 ] )

        if !node.hasvalue || !weight.hasvalue
            warn( "Cannot process recruitment age parameters. Not building recruitment scheme." )
            return
        end   # if !node.hasvalue || ...

        ageDist[ node.value ] = weight.value
    end  # for ii in 1:numNodes

    setAgeDistribution( recScheme, ageDist, distType )

    return recScheme

end  # createRecruitmentScheme( pars )


"""
```
readAttritionFromDatabase( configDB::SQLite.DB,
                           mpSim::ManpowerSimulation,
                           configName::String )
```
This function reads the retirement parameters from the SQLite database
`configDB`, looking in the table with name `configName`, and uses these
parameters to configure the manpower simulation `mpSim`.

This function returns `nothing`. If information is missing, the funuction will
issue warnings, or throw an error depending on the severity.
"""
function readAttritionFromDatabase( configDB::SQLite.DB,
    mpSim::ManpowerSimulation, configName::String )::Void

    queryCmd = "SELECT strPar1 FROM $configName
        WHERE parType IS 'Attrition' AND parName IS 'Attrition'"
    attrition = Array( SQLite.query( configDB, queryCmd ) )

    # If no attrition is in the database, set the attrition scheme to nothing
    #   and finish.
    if length( attrition ) == 0
        setAttrition( mpSim )
        return
    end  # if length( retirement ) == 0

    attrPars = attrition[ 1 ]

    # Default to no attrition if the entry is missing...
    if !isa( attrPars, String )
        warn( "Attrition parameters missing. Setting attrition scheme to none." )
        setAttrition( mpSim )
        return
    end  # if !isa( retPars, String )

    attrPars = split( attrPars, ";" )

    # ... of if it is incorrectly formatted.
    if ( length( attrPars ) < 2 ) ||
        !tryparse( Float64, attrPars[ 1 ] ).hasvalue
        warn( "Attrition parameters incorrectly formatted. Setting attrition scheme to none." )
        setAttrition( mpSim )
        return
    end  # if ( length( attrPars ) < 2 ) || ...

    attrPeriod = tryparse( Float64, attrPars[ 1 ] ).value
    attrPars = split.( attrPars[ 2:end ], "," )
    attrCurvePoints = map( parPair -> parPair[ 1 ], attrPars )
    attrRates = map( parPair -> parPair[ 2 ], attrPars )

    if !all( length.( attrPars ) .== 2 )
        warn( "Attrition parameters incorrectly formatted. Setting attrition scheme to none." )
        setAttrition( mpSim )
        return
    end

    attrCurvePoints = map( curvePoint -> tryparse( Float64, curvePoint ),
        attrCurvePoints )
    attrRates = map( rate -> tryparse( Float64, rate ), attrRates )

    if !all( curvePoint -> curvePoint.hasvalue, attrCurvePoints ) ||
        !all( rate -> rate.hasvalue, attrRates )
        warn( "Attrition parameters incorrectly formatted. Setting attrition scheme to none." )
        setAttrition( mpSim )
        return
    end

    attrCurvePoints = map( curvePoint -> curvePoint.value * 12,
        attrCurvePoints )
    attrRates = map( rate -> rate.value, attrRates )

    # Don't add an attrition scheme if the attrtion curve is a flat 0.
    if ( length( attrRates ) == 1 ) && ( attrRates[ 1 ] == 0 )
        setAttrition( mpSim )
    else
        attrScheme = Attrition( hcat( attrCurvePoints, attrRates ), attrPeriod )
        setAttrition( mpSim, attrScheme )
    end  # if ( length( attrRates ) == 1 ) && ...

    return

end  # readAttritionFromDatabase( configDB, mpSim, configName )


"""
```
readRetirementFromDatabase( configDB::SQLite.DB,
                            mpSim::ManpowerSimulation,
                            configName::String )
```
This function reads the retirement parameters from the SQLite database
`configDB`, looking in the table with name `configName`, and uses these
parameters to configure the manpower simulation `mpSim`.

This function returns `nothing`. If information is missing, the funuction will
issue warnings, or throw an error depending on the severity.
"""
function readRetirementFromDatabase( configDB::SQLite.DB,
    mpSim::ManpowerSimulation, configName::String )::Void

    queryCmd = "SELECT strPar1 FROM $configName
        WHERE parType IS 'Retirement' AND parName IS 'Retirement'"
    retirement = Array( SQLite.query( configDB, queryCmd ) )

    # If no retirement is in the database, set the retirement scheme to nothing
    #   and finish.
    if length( retirement ) == 0
        setRetirement( mpSim )
        return
    end  # if length( retirement ) == 0

    retPars = retirement[ 1 ]

    # Default to no retirement if the entry is missing...
    if !isa( retPars, String )
        warn( "Retirement parameters missing. Setting retirement scheme to none." )
        setRetirement( mpSim )
        return
    end  # if !isa( retPars, String )

    retPars = split( retPars, "," )

    # ... or if it doesn't consist of 4 numbers.
    if ( length( retPars ) != 4 ) ||
        !all( par -> tryparse( Float64, par ).hasvalue, retPars )
        warn( "Retirement parameters incorrectly formatted. Setting retirement scheme to none." )
        setRetirement( mpSim )
        return
    end  # if ( length( retPars ) != 4 ) || ...

    retPars = map( par -> tryparse( Float64, par ).value, retPars )

    if ( retPars[ 1 ] == 0 ) && ( retPars[ 2 ] == 0 )
        setRetirement( mpSim )
    else
        retScheme = Retirement( freq = retPars[ 3 ], offset = retPars[ 4 ],
            maxCareer = retPars[ 1 ], retireAge = retPars[ 2 ] )
        setRetirement( mpSim, retScheme )
    end  # if ( retPars[ 1 ] == 0 ) && ...

    return

end  # readRetirementFromDatabase( configDB, mpSim, configName )