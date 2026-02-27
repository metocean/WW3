program ww3_prnc_sea

      USE netcdf

      IMPLICIT NONE

      INTEGER                     :: fidA, dimID_time, dimID_lon, dimID_lat, &
                                     time_ID, lon_ID, lat_ID, u_var_ID, v_var_ID, &
                                     status, unit_inp, status_missu, status_missv
      INTEGER                     :: ntimes, nlons, nlats
      CHARACTER(LEN=100)          :: file_in, ww3_field_id

      ! input netCDF variables
      REAL,ALLOCATABLE,DIMENSION(:)       :: vartime, lon, lat
      REAL,ALLOCATABLE,DIMENSION(:,:,:)   :: u_var, v_var
      REAL                                :: var_fillval_u, var_fillval_v, &
                                             var_scale_u, var_scale_v, &
                                             var_offset_u, var_offset_v, &
                                             var_missval_u, var_missval_v, &
                                             min_input_lat, max_input_lat
      LOGICAL                             :: is_there_neg_lons

      ! Times
      INTEGER, ALLOCATABLE  :: thetimes(:,:)     ! Array of output date/times to find
      INTEGER :: thetime(2)                      ! date / time --> yyyymmdd hhmmss
      INTEGER :: startdate, starttime            ! Start date/time
      INTEGER :: dt

      ! integer counters
      INTEGER  ::  t, J, i, EXTCDE

      ! SMC grid
      CHARACTER(LEN=100)   ::  smc_cell_file
      INTEGER              ::  NT, NSea, mm, MRL=1
      REAL                 ::  smc_lon0, smc_lat0, smc_dx, smc_dy
      INTEGER, ALLOCATABLE ::  ICE(:,:), ICG(:,:)
      REAL                 ::  cn_lon, cn_lat

      ! Interpolation
      CHARACTER(LEN=100)              :: interp_method
      INTEGER                         :: IX1, IX2, IY1, IY2
      REAL                            :: X1, X2, Y1, Y2, DENOM,          &
                                         dist11, dist12, dist21, dist22, &
                                         W11, W12, W21, W22,             &
                                         min_dist, nearIX, nearIY
      REAL,ALLOCATABLE,DIMENSION(:,:) :: u_var_interp, v_var_interp

      ! WW3 binary file
      INTEGER            ::  unit_out=11, err=0, gtypet=1, filler(3), tidef=0
      CHARACTER(LEN=256) ::  file_out
      LOGICAL            ::  L_first_write
      INTEGER            ::  nx, ny

      ! Output netcdf file with winds
      INTEGER              ::  ncid_out, out_timeID, out_lonID, out_latID, &
                               out_nseaID, out_uID, out_vID
      REAL, ALLOCATABLE    ::  cn_lons(:), cn_lats(:)
      INTEGER,DIMENSION(2) ::  arrdims
      LOGICAL              ::  debug


      filler(:)=0
      L_first_write=.TRUE.
      var_fillval_u=0
      var_fillval_v=0
      var_scale_u=1
      var_scale_v=1
      var_offset_u=0
      var_offset_v=0
      is_there_neg_lons=.FALSE.
      debug = .TRUE.

      ! Open ww3_prnc_sea.inp
      OPEN( unit=unit_inp, file='ww3_prnc_sea.inp', status="old", &
            form="formatted", iostat=err )
      IF( err .NE. 0 ) THEN
            PRINT*,"[ERROR] Failed to open file ww3_prnc_sea.inp"
            PRINT*,"[ERROR] IOERROR: ", err
            EXTCDE = 2
            CALL EXIT(EXTCDE)
      ENDIF

      ! Read parameters
      READ( unit_inp,*,iostat=err ) ww3_field_id
      ww3_field_id = TRIM(ww3_field_id)
      WRITE(*,*) 'ww3_field_id = ', ww3_field_id
      READ( unit_inp,'(A)',iostat=err ) file_in
      file_in = TRIM(file_in)
      WRITE(*,*) 'file_in = ', file_in
      READ( unit_inp,*,iostat=err ) nlons, nlats, ntimes
      nlons = nlons
      nlats = nlats
      ntimes = ntimes
      WRITE(*,*) 'nlons, nlats, ntimes = ', nlons, nlats, ntimes
      READ( unit_inp,*,iostat=err ) startdate, starttime, dt
      dt = dt*3600
      WRITE(*,*) 'startdate, starttime, dt = ', startdate, starttime, dt
      READ( unit_inp,*,iostat=err ) nx, ny
      nx = nx
      ny = ny
      WRITE(*,*) 'nx, ny = ', nx, ny
      READ( unit_inp,'(A)',iostat=err ) smc_cell_file
      smc_cell_file = TRIM(smc_cell_file)
      WRITE(*,*) 'smc_cell_file = ', smc_cell_file
      READ( unit_inp,*,iostat=err ) smc_lon0, smc_lat0
      smc_lon0 = smc_lon0
      smc_lat0 = smc_lat0
      WRITE(*,*) 'smc_lon0, smc_lat0 = ', smc_lon0, smc_lat0
      READ( unit_inp,*,iostat=err ) smc_dx, smc_dy
      smc_dx = smc_dx
      smc_dy = smc_dy
      WRITE(*,*) 'smc_dx, smc_dy = ', smc_dx, smc_dy
      READ( unit_inp,*,iostat=err ) interp_method
      interp_method = TRIM(interp_method)
      WRITE(*,*) 'interp_method = ', interp_method
      CLOSE( unit_inp )

      IF (ww3_field_id .EQ. 'WND') THEN
            file_out = 'wind.ww3'
      ELSEIF (ww3_field_id .EQ. 'CUR') THEN
            file_out = 'current.ww3'
      ENDIF

      ! 1. Open file
      write(*,*) 'Reading ', TRIM(file_in)

      status = NF90_OPEN(TRIM(file_in),0,fidA)
      call errores(status,.TRUE.,"read")

      ! 2. Read dimension IDs
      status = NF90_INQ_DIMID(fidA,"time",dimID_time)
      call errores(status,.TRUE.,"inq_dimID_time")
      !
      status = NF90_INQ_DIMID(fidA,"lon",dimID_lon)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"longitude",dimID_lon)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"Longitude",dimID_lon)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"x",dimID_lon)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"X",dimID_lon)
      call errores(status,.TRUE.,"inq_dimID_lon")
      status = NF90_INQ_DIMID(fidA,"lat",dimID_lat)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"latitude",dimID_lat)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"Latitude",dimID_lat)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"y",dimID_lat)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_DIMID(fidA,"Y",dimID_lat)
      call errores(status,.TRUE.,"inq_dimID_lat")

      ! 3. Read dimension values
      status = NF90_INQUIRE_DIMENSION(fidA,dimID_time,len=ntimes)
      call errores(status,.TRUE.,"inq_dim_time")
      status = NF90_INQUIRE_DIMENSION(fidA,dimID_lon,len=nlons)
      call errores(status,.TRUE.,"inq_dim_lon")
      status = NF90_INQUIRE_DIMENSION(fidA,dimID_lat,len=nlats)
      call errores(status,.TRUE.,"inq_dim_lat")

      ! 4. Allocation of arrays :
      ALLOCATE(  vartime(ntimes)  )
      ALLOCATE(  lon(nlons)  )
      ALLOCATE(  lat(nlats)  )
      ALLOCATE(  u_var(nlons,nlats,ntimes)  )
      ALLOCATE(  v_var(nlons,nlats,ntimes)  )

      ! 5. Read variable IDs
      status = NF90_INQ_VARID(fidA,"time",time_ID)
      call errores(status,.TRUE.,"inq_time_ID")

      status = NF90_INQ_VARID(fidA,"lat",lat_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"latitude",lat_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"Latitude",lat_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"y",lat_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"Y",lat_ID)
      call errores(status,.TRUE.,"inq_lat_ID")
      status = NF90_INQ_VARID(fidA,"lon",lon_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"longitude",lon_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"Longitude",lon_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"x",lon_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"X",lon_ID)
      call errores(status,.TRUE.,"inq_lon_ID")
      status = NF90_INQ_VARID(fidA,"ugrd10m",u_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"u",u_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"uo",u_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"us",u_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"u10",u_var_ID)
      call errores(status,.TRUE.,"inq_ugrd10m_ID")
      status = NF90_INQ_VARID(fidA,"vgrd10m",v_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"v",v_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"vo",v_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"vs",v_var_ID)
      IF ( status/=NF90_NOERR ) status = NF90_INQ_VARID(fidA,"v10",v_var_ID)
      call errores(status,.TRUE.,"inq_vgrd10m_ID")

      ! 6. Read netcdf attributes
      status = NF90_GET_ATT(fidA,u_var_ID,'scale_factor',var_scale_u)
      IF (status.NE.0 ) var_scale_u = 1.0 ! NF90_GET_ATT returns var=0 if not in file
      status = NF90_GET_ATT(fidA,v_var_ID,'scale_factor',var_scale_v)
      IF (status.NE.0 ) var_scale_v = 1.0
      status = NF90_GET_ATT(fidA,u_var_ID,'add_offset',var_offset_u)
      status = NF90_GET_ATT(fidA,v_var_ID,'add_offset',var_offset_v)
      status = NF90_GET_ATT(fidA,u_var_ID,'_FillValue',var_fillval_u)
      status = NF90_GET_ATT(fidA,v_var_ID,'_FillValue',var_fillval_v)
      var_fillval_u = var_fillval_u*var_scale_u + var_offset_u
      var_fillval_v = var_fillval_v*var_scale_v + var_offset_v
      status_missu = NF90_GET_ATT(fidA,u_var_ID,'missing_value',var_missval_u)
      status_missv = NF90_GET_ATT(fidA,v_var_ID,'missing_value',var_missval_v)

      ! 7. Read variable values
      status = NF90_GET_VAR(fidA,time_ID,vartime)
      call errores(status,.TRUE.,"getvar_time")
      status = NF90_GET_VAR(fidA,lon_ID,lon)
      call errores(status,.TRUE.,"getvar_lon")
      status = NF90_GET_VAR(fidA,lat_ID,lat)
      call errores(status,.TRUE.,"getvar_lat")
      status = NF90_GET_VAR(fidA,u_var_ID,u_var)
      call errores(status,.TRUE.,"getvar_u")
      status = NF90_GET_VAR(fidA,v_var_ID,v_var)
      call errores(status,.TRUE.,"getvar_v")

      ! 8. Apply missing_value if it exists then scale_factor/offset
      if (status_missu == 0) WHERE (u_var == var_missval_u) u_var = var_fillval_u
      if (status_missv == 0) WHERE (v_var == var_missval_v) v_var = var_fillval_v
      u_var = (u_var*var_scale_u) + var_offset_u
      v_var = (v_var*var_scale_v) + var_offset_v

      ! ! Get min and max latitudes to limit intepolation
      min_input_lat = MINVAL(lat)
      max_input_lat = MAXVAL(lat)

      ! ! Convert input longitudes to 0-360
      ! lon = MODULO(lon,360.)
      ! WRITE(*,*) 'lon is = ', lon

      ! Check if there are negative longitudes
      ! (i.e., longitudes defined from -180 to 180)
      IF ( ANY( lon<0 ) ) is_there_neg_lons=.TRUE.

      ! 9. Close file
      status = NF90_CLOSE(fidA)
      call errores(status,.TRUE.,"close_file")

      ! 10. Generate times array with startdate starttime and TICK21
      ALLOCATE( thetimes( ntimes, 2 ) )
      thetimes(:,:) = -1
      thetime(1) = startdate
      thetime(2) = starttime
      DO t=1,ntimes
            thetimes(t,1) = thetime(1)
            thetimes(t,2) = thetime(2)
            call TICK21( thetime, REAL(dt) )
      ENDDO

      IF ( debug .EQ. .TRUE. ) THEN
            WRITE(*,*) 'SIZE(thetimes(:,1)) = ', SIZE(thetimes(:,1))
            WRITE(*,*) ' times array: '
            DO t=1,SIZE(thetimes(:,1))
                  WRITE(*,*) t, thetimes(t,1), thetimes(t,2)
            ENDDO
      END IF ! debug


      ! -----------------------------------------------------
      ! ------------------ READ SMC GRID --------------------
      ! -----------------------------------------------------

      ! 1. Read Cell file
      WRITE(*,*) 'Opening ',TRIM(smc_cell_file)

      OPEN( unit=8, file=TRIM(smc_cell_file), status="old", iostat=NT )
      IF ( NT .NE. 0 ) THEN
            WRITE(*,*) 'smc_cell_file was not opened! '
      ENDIF
      READ( 8,* ) NSea
      WRITE(*,*) NSea
      ALLOCATE( ICG(5,NSea) )
      DO J=1,NSea
            READ (8,*) ICG(1,J), ICG(2,J), ICG(3,J), ICG(4,J), ICG(5,J)
      END DO
      CLOSE(8)
      WRITE(*,*) TRIM(smc_cell_file), ' read done ', NSea

      ALLOCATE( ICE(5,-9:NSea) )
      ICE(:,1:NSea)=ICG

      !  Boundary -9 to 0 cells for cell size 2**n
      !  Note the position indices for boundary cell are not used.
      ICE(1,-9:0)=0
      ICE(2,-9:0)=0
      ICE(3,   0)=1
      ICE(4,   0)=1

      !! Restrict boundary cell y-size no more than base cell size 2**(MRL-1).
      mm = 2**(MRL - 1)
      DO J=1,9
            ICE(3,-J)=ICE(3,-J+1)*2
            ICE(4,-J)=MIN(mm, ICE(3,-J))
      ENDDO

      ALLOCATE( u_var_interp(ntimes, NSea) )
      ALLOCATE( v_var_interp(ntimes, NSea) )

      !---------------------------------------------
      !--- INTERPOLATE AND WRITE WW3 BINARY FILE ---
      !---------------------------------------------

      ! 1. Open file
      OPEN( unit=unit_out, file=file_out, status='replace',            &
            form='unformatted', position='rewind', iostat=err )

      IF( err .NE. 0 ) THEN
            PRINT*,"[ERROR] Failed to open file: " // TRIM(file_out) //   &
                   " for writing."
            PRINT*,"[ERROR]    IOERROR: ", err
      ENDIF

      ! 1.1 Generate cn_lons and cn_lats arrays (this is for the netcdf debug file)
      ALLOCATE( cn_lons(NSea) )
      ALLOCATE( cn_lats(NSea) )

      DO i=1,NSea
            cn_lons(i) = smc_lon0 + (ICE(1,i) + 0.5*ICE(3,i)) * smc_dx
            cn_lats(i) = smc_lat0 + (ICE(2,i) + 0.5*ICE(4,i)) * smc_dy
      END DO

      ! 2. MAIN LOOP. Loop through times, smc nodes and field components,
      !               interpolate data and write to file_out
      DO t=1,ntimes

            IF( L_first_write ) THEN
                  L_first_write = .FALSE.

                  CALL ww3_write_header( unit_out, ww3_field_id, &
                         nx, ny, gtypet, filler(1:2), tidef, err )
            ENDIF

            DO i=1,NSea

                  ! SMC grid centre cell (for this "i"):
                  cn_lon = smc_lon0 + (ICE(1,i) + 0.5*ICE(3,i)) * smc_dx
                  cn_lat = smc_lat0 + (ICE(2,i) + 0.5*ICE(4,i)) * smc_dy

                  ! Modify SMC cn_lons if there are negative longitudes in input data
                  IF ( is_there_neg_lons ) THEN
                        IF ( cn_lon > 180 ) THEN
                              cn_lon = cn_lon - 360
                        ENDIF
                  ENDIF

                  ! Get grid points in the input file surrounding (cn_lon, cn_lat)
                  CALL closest(SIZE(lon), lon, cn_lon, IX1)
                  IX2=IX1+1
                  CALL closest(SIZE(lat), lat, cn_lat, IY1)
                  IY2=IY1+1

                  X1=lon(IX1)
                  X2=lon(IX2)
                  Y1=lat(IY1)
                  Y2=lat(IY2)

                  IF ((cn_lat>max_input_lat ) .OR. (cn_lat<min_input_lat)) THEN
                        u_var_interp(t,i) = 0
                        v_var_interp(t,i) = 0
                  ELSE
                        ! ################################
                        ! ###   FORCING INTERPOLATION  ###
                        ! ################################
                        IF ((ww3_field_id .EQ. 'WND') .AND. (interp_method .EQ. 'bilinear')) THEN

                              ! Bi-linear interpolation optional for winds only
                              DENOM = (X2-X1)*(Y2-Y1)

                              u_var_interp(t,i) = ((X2-cn_lon)*(Y2-cn_lat)*u_var(IX1, IY1, t))/DENOM + &
                                                  ((cn_lon-X1)*(Y2-cn_lat)*u_var(IX2, IY1, t))/DENOM + &
                                                  ((X2-cn_lon)*(cn_lat-Y1)*u_var(IX1, IY2, t))/DENOM + &
                                                  ((cn_lon-X1)*(cn_lat-Y1)*u_var(IX2, IY2, t))/DENOM

                              v_var_interp(t,i) = ((X2-cn_lon)*(Y2-cn_lat)*v_var(IX1, IY1, t))/DENOM + &
                                                  ((cn_lon-X1)*(Y2-cn_lat)*v_var(IX2, IY1, t))/DENOM + &
                                                  ((X2-cn_lon)*(cn_lat-Y1)*v_var(IX1, IY2, t))/DENOM + &
                                                  ((cn_lon-X1)*(cn_lat-Y1)*v_var(IX2, IY2, t))/DENOM

                        ! Inverse distance weighting
                        ELSEIF (interp_method .EQ. 'idw') THEN

                              CALL haversine(Y1, X1, cn_lat, cn_lon, dist11)
                              CALL haversine(Y1, X2, cn_lat, cn_lon, dist12)
                              CALL haversine(Y2, X1, cn_lat, cn_lon, dist21)
                              CALL haversine(Y2, X2, cn_lat, cn_lon, dist22)

                              IF (dist11<0.1) THEN
                                    W11=1; W12=0; W21=0; W22=0;
                              ELSEIF (dist12<0.1) THEN
                                    W11=0; W12=1; W21=0; W22=0;
                              ELSEIF (dist21<0.1) THEN
                                    W11=0; W12=0; W21=1; W22=0;
                              ELSEIF (dist22<0.1) THEN
                                    W11=0; W12=0; W21=0; W22=1
                              ELSE
                                    W11 = 1/(dist11)
                                    W12 = 1/(dist12)
                                    W21 = 1/(dist21)
                                    W22 = 1/(dist22)
                              ENDIF

                              DENOM = (W11+W12+W21+W22)

                              u_var_interp(t,i) = W11*u_var(IX1, IY1, t)/DENOM + &
                                                  W12*u_var(IX2, IY1, t)/DENOM + &
                                                  W21*u_var(IX1, IY2, t)/DENOM + &
                                                  W22*u_var(IX2, IY2, t)/DENOM
                              v_var_interp(t,i) = W11*v_var(IX1, IY1, t)/DENOM + &
                                                  W12*v_var(IX2, IY1, t)/DENOM + &
                                                  W21*v_var(IX1, IY2, t)/DENOM + &
                                                  W22*v_var(IX2, IY2, t)/DENOM

                        ENDIF ! interp_method

                  ENDIF ! cn_lat >/< then min/max_input_lat

            ENDDO ! i=1,NSea

            DO i=1,2
                  IF( i .eq. 1 ) THEN
                      ! timestamp only output before 1st field
                      CALL ww3_write_field( unit_out, thetimes(t,1),        &
                                            thetimes(t,2), u_var_interp(t,:), NSea, err )
                  ELSE
                      ! set date/time to -1 to surpess timestamp output
                      CALL ww3_write_field( unit_out, -1,                   &
                                            -1, v_var_interp(t,:), NSea, err )
                  ENDIF

              ENDDO ! i=1,n_components

      ENDDO ! t=1,ntimes

      CLOSE( unit_out )

      IF ( debug .EQ. .TRUE. ) THEN
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            !      WRITE NETCDF FILE (DEBUG)     !
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            IF (ww3_field_id .EQ. 'WND') THEN
                  status = NF90_CREATE(PATH='wind_prnc_sea.nc', CMODE=NF90_NETCDF4, ncid=ncid_out)
                  CALL errores(status,.TRUE.,'open_out_ncfile')
            ELSEIF (ww3_field_id .EQ. 'CUR') THEN
                  status = NF90_CREATE(PATH='cur_prnc_sea.nc', CMODE=NF90_NETCDF4, ncid=ncid_out)
                  CALL errores(status,.TRUE.,'open_out_ncfile')
            END IF

            ! Define dimensions
            status = NF90_DEF_DIM(ncid_out, 'time', ntimes, out_timeID)
            CALL errores(status,.TRUE.,'def_time_dim')
            status = NF90_DEF_DIM(ncid_out, 'seapoint', NSea, out_nseaID)
            CALL errores(status,.TRUE.,'def_nsea_dim')

            ! Define variables
            arrdims = (/ out_timeID, out_nseaID /)
            status = NF90_DEF_VAR(ncid_out, 'u', NF90_FLOAT, arrdims, out_uID)
            CALL errores(status,.TRUE.,'def_u_var')
            status = NF90_DEF_VAR(ncid_out, 'v', NF90_FLOAT, arrdims, out_vID)
            CALL errores(status,.TRUE.,'def_v_var')

            status = NF90_DEF_VAR(ncid_out, 'longitude', NF90_FLOAT, (/ out_nseaID /), out_lonID)
            CALL errores(status,.TRUE.,'def_lon_var')
            status = NF90_DEF_VAR(ncid_out, 'latitude', NF90_FLOAT, (/ out_nseaID /), out_latID)
            CALL errores(status,.TRUE.,'def_lat_var')
            status = NF90_DEF_VAR(ncid_out, 'time', NF90_DOUBLE, (/ out_timeID /), out_timeID)
            CALL errores(status,.TRUE.,'def_time_var')

            status = NF90_ENDDEF(ncid_out)
            CALL errores(status,.TRUE.,'enddef')

            ! Put variable fields in file
            status = NF90_PUT_VAR(ncid_out, out_lonID, cn_lons)
            CALL errores(status,.TRUE.,'put_lon_var')
            status = NF90_PUT_VAR(ncid_out, out_latID, cn_lats)
            CALL errores(status,.TRUE.,'put_lat_var')
            status = NF90_PUT_VAR(ncid_out, out_timeID, vartime)
            CALL errores(status,.TRUE.,'put_time_var')
            status = NF90_PUT_VAR(ncid_out, out_uID, u_var_interp)
            CALL errores(status,.TRUE.,'put_u_var')
            status = NF90_PUT_VAR(ncid_out, out_vID, v_var_interp)
            CALL errores(status,.TRUE.,'put_v_var')

            ! Close file
            status = NF90_CLOSE(ncid_out)
            CALL errores(status,.TRUE.,'close_out_ncfile')

      END IF ! debug

      ! Finally. Deallocate arrays
      DEALLOCATE(  vartime  )
      DEALLOCATE(  lon  )
      DEALLOCATE(  lat  )
      DEALLOCATE( u_var )
      DEALLOCATE( v_var )
      DEALLOCATE( u_var_interp )
      DEALLOCATE( v_var_interp )
      DEALLOCATE( ICE )
      DEALLOCATE( ICG )
      DEALLOCATE( thetimes )

      DEALLOCATE( cn_lons )
      DEALLOCATE( cn_lats )

end program ww3_prnc_sea


SUBROUTINE closest(length, array, value, binarysearch)
      ! Given an array and a value, returns the index of the element that
      ! is closest to, but less than, the given value.
      ! Uses a binary search algorithm.
      ! "delta" is the tolerance used to determine if two values are equal
      ! if ( abs(x1 - x2) <= delta) then
      !    assume x1 = x2
      ! endif

      IMPLICIT NONE

      REAL :: delta

      INTEGER, INTENT(IN) :: length
      REAL, DIMENSION(length), INTENT(IN) :: array
      REAL, INTENT(IN) :: value
      INTEGER :: binarysearch
      INTEGER :: left, middle, right

      delta=0.01

      left = 1
      right = length
      DO
            IF (left > right) THEN
                  EXIT
            ENDIF

            middle = nint((left+right) / 2.0)
            IF ( abs(array(middle) - value) <= delta) THEN
                  binarysearch = middle
                  return
            ELSE IF (array(middle) > value) THEN
                  right = middle - 1
            ELSE
                  left = middle + 1
            ENDIF

      ENDDO
      binarysearch = right

END SUBROUTINE closest

SUBROUTINE deg2rad(degree, rad)
      REAL, INTENT(IN) :: degree
      REAL, PARAMETER  :: deg_to_rad = atan(1.0)/45
      REAL             :: rad

      rad = degree*deg_to_rad
END SUBROUTINE deg2rad

!

SUBROUTINE haversine(deglat1, deglon1, deglat2, deglon2, dist)
      ! Great circle distance calculator
      REAL, INTENT(IN) :: deglat1, deglon1, deglat2, deglon2
      REAL             :: h_a, h_c, h_dist, h_dlat, h_dlon, h_lat1, h_lat2
      REAL, PARAMETER  :: radius = 6372.8

      CALL deg2rad(deglat2-deglat1, h_dlat)
      CALL deg2rad(deglon2-deglon1, h_dlon)
      CALL deg2rad(deglat1, h_lat1)
      CALL deg2rad(deglat2, h_lat2)

      h_a = (sin(h_dlat/2))**2 + cos(h_lat1)*cos(h_lat2)*(sin(h_dlon/2))**2
      h_c = 2*asin(sqrt(h_a))
      dist = radius*h_c

END SUBROUTINE haversine

!

SUBROUTINE ww3_write_header( unit, fld, nx, ny, gtypet, filler, tidef, err )

      IMPLICIT NONE

      INTEGER, INTENT(IN)       :: unit, nx, ny, gtypet, filler(3), tidef
      INTEGER, INTENT(INOUT)    :: err
      CHARACTER(*), INTENT(IN)  :: fld

      ! Work
      INTEGER(KIND=4) :: nx32, ny32, gtypet32, filler32(3), tidef32

      ! convert to 32 bit:
      nx32 = nx
      ny32 = ny
      gtypet32 = gtypet
      filler32 = filler
      tidef32 = tidef

      ! Write WW3 header:
      WRITE(*,*) "WAVEWATCH III", fld(1:3), nx32, ny32,  &
                                    gtypet32, filler32(1:2), tidef32
      WRITE( unit, iostat=err ) "WAVEWATCH III", fld(1:3), nx32, ny32,  &
                                    gtypet32, filler32(1:2), tidef32

      IF( err .ne. 0 ) THEN
            print*,"[ERROR] Error writing file header", err
            return
      ENDIF

END SUBROUTINE ww3_write_header

!

SUBROUTINE ww3_write_field( unit, date, ftime, data, NSea, err )

      IMPLICIT NONE

      INTEGER, INTENT(IN)       :: unit, date, ftime, NSea
      INTEGER, INTENT(INOUT)    :: err
      REAL, INTENT(IN)          :: data(NSea)

      ! Work:
      INTEGER(KIND=4) :: date32, ftime32, NSea32
      REAL(KIND=4)    :: data32(NSea)
      INTEGER :: i, j


      ! convert data:
      date32 = date
      ftime32 = ftime
      NSea32 = NSea

      DO i=1,NSea
            data32(i) = data(i)
      ENDDO

      ! Write time, if required:
      IF( date32 .NE. -1 ) THEN
          WRITE( unit, iostat=err ) date32, ftime32, NSea32
          IF( err .ne. 0 ) THEN
              print*,"[ERROR] Error writing date/time", err
              return
          ENDIF
      ENDIF

      ! Write data:
      WRITE( unit, IOSTAT=err ) data32
      IF( err .ne. 0 ) THEN
          print*,"[ERROR] Error writing field data", err
          return
      ENDIF

END SUBROUTINE ww3_write_field

!

SUBROUTINE errores(iret, lstop, func)

      USE netcdf

      INTEGER, INTENT(in)                     :: iret
      LOGICAL, INTENT(in)                     :: lstop
      CHARACTER(LEN=*), INTENT(in)            :: func
      !
      CHARACTER(LEN=80)                       :: message
      !
      IF ( iret .NE. 0 ) THEN
            WRITE(*,*) 'ROUTINE: ', TRIM(func)
            WRITE(*,*) 'ERRoR: ', iret
            message=NF90_STRERROR(iret)
            WRITE(*,*) 'Message:',TRIM(message)
            IF ( lstop ) STOP
      ENDIF

END SUBROUTINE errores

!

SUBROUTINE TICK21 ( TIME, DTIME )
      !/
            IMPLICIT NONE
      !/
      !/ Parameter list
      !/
            INTEGER, INTENT(INOUT)  :: TIME(2)
            REAL, INTENT(IN)        :: DTIME
      !/
      !/ Local parameters
      !/
            INTEGER                 :: NYMD, NHMS, NSEC
      !/
      !
            NYMD   = TIME(1)
            NHMS   = TIME(2)
            IF (DTIME.EQ.0.) THEN
            NYMD = IYMD21 (NYMD,-1)
            NYMD = IYMD21 (NYMD, 1)
            END IF
      !
      ! Convert and increment time :
      !
            NSEC = NHMS/10000*3600 + MOD(NHMS,10000)/100* 60 +        &
                  MOD(NHMS,100) + NINT(DTIME)
      !
      ! Check change of date :
      !
      100 CONTINUE
            IF (NSEC.GE.86400)  THEN
            NSEC = NSEC - 86400
            NYMD = IYMD21 (NYMD,1)
            GOTO 100
            END IF
      !
      200 CONTINUE
            IF (NSEC.LT.00000)  THEN
            NSEC = 86400 + NSEC
            NYMD = IYMD21 (NYMD,-1)
            GOTO 200
            END IF
      !
            NHMS = NSEC/3600*10000 + MOD(NSEC,3600)/60*100 + MOD(NSEC,60)
      !
            TIME(1) = NYMD
            TIME(2) = NHMS
      !
            RETURN
      !/
      !/ Internal function IYMD21 ------------------------------------------ /
      !/
            CONTAINS

      !/ ------------------------------------------------------------------- /
            INTEGER FUNCTION IYMD21 ( NYMD ,M )
      !/
            IMPLICIT NONE
      !/
      !/ Parameter list
      !/
            INTEGER, INTENT(IN)     :: NYMD, M
      !/
      !/ Local parameters
      !/
            INTEGER                 :: NY, NM, ND
            INTEGER, SAVE           :: NDPM(12)
            DATA     NDPM / 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /
            LOGICAL                 :: LEAP
      !/
            NY   = NYMD / 10000
            NM   = MOD(NYMD,10000) / 100
            NM   = MIN ( 12 , MAX(1,NM) )
            ND   = MOD(NYMD,100) + M
            LEAP = MOD(NY,400).EQ.0 .OR.                              &
                  ( MOD(NY,4).EQ.0 .AND. MOD(NY,100).NE.0 )
      !
      ! M = -1, change month if necessary :
      !
            IF (ND.EQ.0) THEN
            NM   = NM - 1
            IF (NM.EQ.0) THEN
                  NM   = 12
                  NY   = NY - 1
                  ENDIF
            ND   = NDPM(NM)
            IF (NM.EQ.2 .AND. LEAP)  ND = 29
            END IF
      !
      ! M = 1, leap year
      !
            IF (ND.EQ.29 .AND. NM.EQ.2 .AND. LEAP)  GO TO 20
      !
      !        next month
      !
            IF (ND.GT.NDPM(NM)) THEN
            ND = 1
            NM = NM + 1
            IF (NM.GT.12) THEN
                  NM = 1
                  NY = NY + 1
            ENDIF
            END IF
      !
      20 CONTINUE
            IYMD21 = NY*10000 + NM*100 + ND
      !
            RETURN
      !/
      !/ End of IYMD21 ----------------------------------------------------- /
      !/
            END FUNCTION IYMD21
      !/
      !/ End of TICK21 ----------------------------------------------------- /
      !/
END SUBROUTINE TICK21

!

REAL FUNCTION DSEC21 ( TIME1, TIME2 )
      !/
      !/
            IMPLICIT NONE
      !/
      !/ Parameter list
      !/
            INTEGER, INTENT(IN)     :: TIME1(2), TIME2(2)
      !/
      !/ Local parameters
      !/
            INTEGER                 :: NY1, ND1, NY2, ND2, NS1, NS2, NS,   &
                                    ND, NST
      ! Convert dates and times :
      !
            NY1    = TIME1(1) / 10000
            ND1    = MYMD21 ( TIME1(1) )
            NS1    = TIME1(2)/10000*3600 + MOD(TIME1(2),10000)/100*60 + &
                  MOD(TIME1(2),100)
      !
            NY2    = TIME2(1) / 10000
            ND2    = MYMD21 ( TIME2(1) )
            NS2    = TIME2(2)/10000*3600 + MOD(TIME2(2),10000)/100*60 + &
                  MOD(TIME2(2),100)
      !
      ! Number of days and seconds in difference :
      !
            ND     = ND2 - ND1
      !
            IF ( NY1 .NE. NY2 ) THEN
            NST    = SIGN ( 1 , NY2-NY1 )
      100     CONTINUE
            IF (NY1.EQ.NY2) GOTO 200
            IF (NST.GT.0) THEN
                  NY2    = NY2 - 1
                  ND     = ND  + MYMD21 ( NY2*10000 + 1231 )
                  ELSE
                  ND     = ND  - MYMD21 ( NY2*10000 + 1231 )
                  NY2    = NY2 + 1
                  ENDIF
            GOTO 100
      200     CONTINUE
            END IF
      !
            NS     = NS2 - NS1
      !
      ! Output of time difference :
      !
            DSEC21 = REAL(NS) + 86400.*REAL(ND)
      !
            RETURN
      !/
      !/ Internal function MYMD21 ------------------------------------------ /
      !/
            CONTAINS
      !/ ------------------------------------------------------------------- /
            INTEGER FUNCTION MYMD21 ( NYMD )
      !/
      !/
            IMPLICIT NONE
      !/
      !/ Parameter list
      !/
            INTEGER, INTENT(IN)     :: NYMD
      !/
      !/ Local parameters
      !/
            INTEGER                 :: NY, NM, ND
            INTEGER, SAVE           :: NDPM(12)
            DATA    NDPM / 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /
            LOGICAL                 :: LEAP
      !/
      ! "Unpack" and increment date :
      !
            NY   = NYMD / 10000
            NM   = MOD(NYMD,10000) / 100
            ND   = MOD(NYMD,100)
            LEAP = MOD(NY,400).EQ.0 .OR.                              &
                  ( MOD(NY,4).EQ.0 .AND. MOD(NY,100).NE.0 )
      !
      ! Loop over months :
      !
            IF (NM.GT.2 .AND. LEAP)  ND = ND + 1
      !
      40 CONTINUE
            IF (NM.LE.1)  GO TO 60
            NM = NM - 1
            ND = ND + NDPM(NM)
            GO TO 40
      !
      60 CONTINUE
            MYMD21 = ND
      !
            RETURN
      !/
      !/ End of MYMD21 ----------------------------------------------------- /
      !/
            END FUNCTION MYMD21
      !/
      !/ End of DSEC21 ----------------------------------------------------- /
      !/
END FUNCTION DSEC21
