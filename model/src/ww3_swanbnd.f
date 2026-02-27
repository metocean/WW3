c***********************************************************************
c                                                                      *
      program ww3_swanbnd

      integer mdc,msc,mip,mip2,mipb,time(2),isp, kk
      real,allocatable::spcdir(:),spcsig(:),acloc(:,:,:),spec(:,:)
      real,allocatable::xp(:),yp(:),rf(:,:),bufin(:,:)
      integer,allocatable::irf(:,:)
      character :: inpfil*100
c      character :: filenm*100
      character :: IDTST*32, VERTST*10
      integer ierr,iostat,nref,ndsb,nfin,i,ifile
      logical BNAUT

      real th1,flow,ffac,dth,efac,pi,dfac

      BNAUT=.TRUE.
      NREF=6
      ndsb=11
      IERR = -1
c      OFAC = RHO * GRAV
      pi=4.*atan(1.0)
      dfac=2. * PI**2 / 180.


      write(0,*) 'WW3 to SWAN boundary converter'
      nfin=iargc()
      write(0,*) nfin,' input files>'

      if (nfin.le.0) then
            write(0,*) 'No input file specified'
            write(0,*) 'Use: ww3_swanbnd <ww3bndfile>'
            stop
      endif

      do ifile=1,nfin
      call getarg(ifile,inpfil)
      open(unit=ndsb,file=inpfil,iostat=IERR,status='old',
     &form='unformatted')
        IF (IERR.NE.0) THEN
            write(0,*) 'Error opening ',inpfil
            stop
      ELSE
            write(0,*) 'Opening input file ',inpfil
      ENDIF
      READ (NDSB,IOSTAT=IERR)
     &     IDTST, VERTST, msc, mdc, ffac, flow, th1, mip
      write(0,*) 'Header:',IDTST,VERTST,msc,mdc,ffac,flow,th1,mip

      allocate(spcdir(mdc))
      allocate(spcsig(msc))
      write(0,*) mdc, msc
      allocate(spec(mdc,msc))
      allocate(xp(mip),yp(mip),irf(mip,4),rf(mip,4))
c
       READ (NDSB,IOSTAT=IERR)(xp(I),I=1,mip),(yp(I),I=1,mip),
     *   ((irf(I,J),I=1,mip),J=1,4), ((rf(I,J),I=1,mip),J=1,4)

c      do ip=1,mip
c      print*,xp(ip),yp(ip),irf(ip,:),rf(ip,:)
c      enddo

      mipb=0
      do ip=1,MIP-1
            if (xp(ip).ne.xp(ip+1).or.yp(ip).ne.yp(ip+1)) then
            mipb=mipb+1
            xp(mipb)=xp(ip)
            yp(mipb)=yp(ip)
            irf(mipb,:)=irf(ip,:)
            rf(mipb,:)=rf(ip,:)
            endif
      enddo

      spcsig(1)=flow
      do ip=2,msc
            spcsig(ip)=ffac*spcsig(ip-1)
      enddo
      spcdir(1)=th1
      dth=(360/mdc)
      do ip=2,mdc
            spcdir(ip)=spcdir(ip-1)+dth
      enddo

c       open(unit=NREF,file=filenm,iostat=IERR,status='replace')
c        IF (IERR.NE.0) THEN
c            Print*,'Error opening ',filenm
c            stop
c      ELSE
c            Print*,'Opening output file ',filenm
c      ENDIF
      if (ifile.eq.1) then
        WRITE (NREF, 101) 1
 101    FORMAT ('SWAN', I4, T41, 'Swan standard spectral file, version')
        WRITE (NREF, 111)
 111    FORMAT ('$   Data produced by ww3_swanbnd')
        WRITE (NREF, 113)
 113    FORMAT ('$   WW3 converted boundary file')
      WRITE (NREF, 102) 'TIME', 'time-dependent data'
 102      FORMAT (A, T41, A)
        WRITE (NREF, 103) 1, 'time coding option'
 103      FORMAT (I6, T41, A)

        WRITE (NREF, 102) 'LONLAT',
     &                    'locations in spherical coordinates'
        WRITE (NREF, 103) MIPb, 'number of locations'
        DO IP = 1, MIPb
          WRITE (NREF, FMT='(2F12.6)') DBLE(xp(IP)),DBLE(yp(IP))
      ENDDO
        WRITE (NREF, 102) 'AFREQ', 'absolute frequencies in Hz'
      WRITE (NREF, 103) MSC, 'number of frequencies'
        DO IS = 1, MSC
          WRITE (NREF, 114) SPCSIG(IS)
 114      FORMAT (F10.4)
      ENDDO
        WRITE (NREF, 102) 'NDIR',
     &                        'spectral nautical directions in degr'

        WRITE (NREF, 103) MDC, 'number of directions'
        DO 130 ID = 1, MDC
            WRITE (NREF, 124) 270.-SPCDIR(ID)
 124      FORMAT (F10.4)
 130    CONTINUE

        WRITE (NREF, 132) 1
 132    FORMAT ('QUANT', /, I6, T41, 'number of quantities in table')
        WRITE (NREF, 102) 'VaDens',
     &                        'variance densities in m2/Hz/degr'
        WRITE (NREF, 102) 'm2/Hz/degr', 'unit'
        WRITE (NREF, 104) -99., 'exception value'
 104        FORMAT (E14.4, T41, A)
c
c     writing of heading is completed, write time if nonstationary
c
      endif

      do while (.True.)

      READ (NDSB,END=911,IOSTAT=IERR) TIME, mip2
      if (.not.allocated(acloc))then
c            write(0,*),'allocating ',mdc*msc,mip2
            allocate(acloc(mdc,msc,mip2),bufin(mdc,msc))
      endif
c       print*,time(1),time(2),mip2
      WRITE (NREF, 202) time(1),time(2)
 202    FORMAT (I8,'.',I6.6, T41, 'date and time')

      do ip=1,mip2
      READ (NDSB,IOSTAT=IERR) bufin
      acloc(:,:,ip)=bufin
      enddo
c      write(0,*) 'WTF', irf
c      write(0,*) 'WTF2', ACLOC

      do ibi=1,mipb

       efac=0.
       DO is=1,msc
       do id=1,mdc
c       Tom Durrant 24/05/18
c       This section of the code was causing segfaults as irf(ibi,1-3)
c       are always zero, and memory issues when the zero element of ACLOC
c       is accessed. As far as I can tell, ACLOC(id,is,0) is always zero
c       anyway, and so does not contribute to the addition below. As
c       such, the solution is simply to remove these references from the
c       code. The are commented here for future debugging if needed.
       !write(0,*) irf(ibi,1)
       !write(0,*) irf(ibi,2)
       !write(0,*) irf(ibi,3)
       !write(0,*) irf(ibi,4)
       !write(0,*) ACLOC(id,is,irf(ibi,1))
       !write(0,*) ACLOC(id,is,irf(ibi,2))
       !write(0,*) ACLOC(id,is,irf(ibi,3))
       !write(0,*) ACLOC(id,is,irf(ibi,4))
        ISP=msc*(is-1)+id
           spec(id,is) = 0
           do kk=1,4
            if (irf(ibi,kk) .gt. 0) then
               spec(id,is) = spec(id,is) +
     &                       (rf(IBI,kk)*ACLOC(id,is,irf(ibi,kk)))
            endif
           enddo
           spec(id,is) =  dfac * spec(id,is)
c          spec(id,is) = dfac*
c     &    (rf(IBI,1)*ACLOC(id,is,irf(ibi,1)) +
c     &    rf(IBI,2)*ACLOC(id,is,irf(ibi,2)) +
c     &    rf(IBI,3)*ACLOC(id,is,irf(ibi,3)) +
c     &    rf(IBI,4)*ACLOC(id,is,irf(ibi,4)) )

          EFAC = MAX (EFAC, spec(ID,IS))
       enddo
       enddo

       IF (EFAC .LE. 1.E-10) THEN
              WRITE (NREF, 12) 'NODATA'
  12          FORMAT (A6)
       ELSE
              EFAC = 1.01 * EFAC * 10.**(-4)
c       factor PI/180 introduced to account for change from rad to degr
c       factor 2*PI to account for transition from rad/s to Hz
              WRITE (NREF, 95) EFAC
  95          FORMAT ('FACTOR', /, E18.8)
          DO IS = 1, MSC
c          write spectral energy densities to file
          WRITE (NREF,'(200(1X,I4))')(NINT(spec(ID,IS)/EFAC),ID=1,MDC)
          ENDDO
         ENDIF


      enddo

      enddo
c
c    911      Print*,'End of read - closing all files'
911      continue
c      close(nref)
      close(ndsb)
      enddo

      END
