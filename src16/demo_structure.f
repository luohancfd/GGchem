***********************************************************************
      SUBROUTINE DEMO_STRUCTURE
***********************************************************************
      use PARAMETERS,ONLY: Tmin,Tmax,pmin,pmax,nHmin,nHmax,
     >                     model_eqcond,model_pconst,Npoints,
     >                     model_struc,struc_file
      use CHEMISTRY,ONLY: NELM,NMOLE,elnum,cmol,catm,el,charge
      use DUST_DATA,ONLY: NELEM,NDUST,elnam,eps0,bk,bar,muH,mass,
     >                    amu,dust_nam,dust_mass,dust_Vol,
     >                    dust_nel,dust_el,dust_nu
      use EXCHANGE,ONLY: nel,nat,nion,nmol,H,C,N,O,W
      use STRUCTURE,ONLY: Npmax,Tgas,press,pelec,dens,nHtot,estruc
      implicit none
      integer,parameter :: qp = selected_real_kind ( 33, 4931 )
      real(kind=qp) :: eps(NELEM),Sat(NDUST),eldust(NDUST),out(NDUST)
      real :: dat(1000),ddust
      real :: tau,p,pe,Tg,rho,nHges,nges,kT,pges,mu,muold
      real :: Jstar,Nstar,rhog,dustV,rhod
      integer :: i,j,k,e,jj,iz,dk,NOUT,Nfirst,Nlast,Ninc,iW
      integer :: n1,n2,n3,n4,n5,Ndat,dind(1000)
      integer :: verbose=0
      character(len=20000) :: header
      character(len=200) :: line,filename
      character(len=20) :: name,short_name(NDUST),dname,ename
      character(len=1) :: char
      logical :: hasW

      !-----------------------------
      ! ***  read the structure  ***
      !-----------------------------
      filename = 'structures/'//trim(struc_file)
      print*,"reading "//trim(filename)//" ..."

      !--------------------------------------------------------
      if (model_struc==1) then
      !--------------------------------------------------------
        open(3,file=filename,status='old')
        Npoints = 256 
        do i=1,5+Npoints+2 
          read(3,'(A200)') line
        enddo  
        do i=1,Npoints 
          read(3,*) iz,tau,Tg,p,pe,rho
          print*,iz
          Tgas(i)  = Tg
          press(i) = p
          pelec(i) = pe
          dens(i)  = rho
          nHtot(i) = rho/muH
          estruc(i,:) = eps0(:)
        enddo
        close(3)
        Nfirst = Npoints
        Nlast  = 2
        Ninc   = -1  ! botton to top

      !--------------------------------------------------------
      else if (model_struc==2) then
      !--------------------------------------------------------
        open(3,file=filename,status='old')
        Npoints = 48
        do i=1,2
          read(3,'(A200)') line
        enddo  
        do i=1,Npoints 
          read(3,*) Tg,p
          Tgas(i)  = Tg
          press(i) = p*bar
          estruc(i,:) = eps0(:)
        enddo
        close(3)
        model_pconst = .true.
        Nfirst = Npoints
        Nlast  = 2
        Ninc   = -1  ! botton to top

      !--------------------------------------------------------
      else if (model_struc==3) then
      !--------------------------------------------------------
        open(3,file=filename,status='old')
        read(3,'(A200)') line
        read(3,*) n1,n2,n3,n4,n5,Npoints
        Ndat = 5 + 2*n1 + n2 + 2*n3
        read(3,'(A20000)') header
        do j=Ndat-n1-n3+1,Ndat-n1
          dname = adjustl(header(j*20-19:j*20))
          dname = trim(dname(2:))//"[s]"
          dind(j) = 0
          do dk=1,NDUST
            if (trim(dust_nam(dk))==trim(dname)) then
              print*,dk,trim(dust_nam(dk))//" = "//trim(dname) 
              dind(j) = dk
            endif  
          enddo
          if (dind(j)==0) then
            print*,"*** dust kind "//trim(dname)//" not found."
            stop
          endif  
        enddo  
        do k=1,NELM-1
          j = 5 + n1 + n2 + 2*n3 + k
          e = elnum(k)
          ename = adjustl(header(j*20-19:j*20))
          print*,e,"eps"//trim(elnam(e))//" = "//trim(ename)
          if (trim(ename).ne."eps"//trim(elnam(e))) then
            stop "*** something is wrong."
          endif  
        enddo    
        do i=1,Npoints
          read(3,*) dat(1:Ndat) 
          Tgas(i)  = dat(1)
          press(i) = dat(3)
          pelec(i) = 10.d0**dat(5)*bk*Tgas(i)
          dens(i)  = dat(2)*muH
          nHtot(i) = dat(2)
          estruc(i,:) = eps0(:)          
          do k=1,NELM-1
            j = 5 + n1 + n2 + 2*n3 + k
            e = elnum(k) 
            estruc(i,e) = 10.Q0**dat(j)
          enddo   
          do j=Ndat-n1-n3+1,Ndat-n1
            ddust = 10.Q0**dat(j)
            dk = dind(j)
            do k=1,dust_nel(dk)
              e = dust_el(dk,k)
              estruc(i,e) = estruc(i,e) + ddust*dust_nu(dk,k)    
            enddo
          enddo  
          !do k=1,NELM-1
          !  e = elnum(k) 
          !  print'(I3,A3,2(1pE18.10))',i,elnam(e),eps0(e),estruc(i,e) 
          !enddo  
        enddo
        close(3)
        Nfirst = 1
        Nlast  = Npoints
        Ninc   = 1           ! botton to top

      else
        print*,"*** unknown file format =",model_struc
        stop
      endif  

      !----------------------------
      ! ***  open output files  ***
      !----------------------------
      do i=1,NDUST
        name = dust_nam(i) 
        j=index(name,"[s]")
        short_name(i) = name
        if (j>0) short_name(i)=name(1:j-1)
      enddo
      eps  = eps0
      NOUT = NELM
      if (charge) NOUT=NOUT-1
      open(unit=70,file='Static_Conc.dat',status='replace')
      write(70,1000) 'H',eps( H), 'C',eps( C),
     &               'N',eps( N), 'O',eps( O)
      write(70,*) NOUT,NMOLE,NDUST,Npoints
      write(70,2000) 'Tg','nHges','pges','el',
     &               (trim(elnam(elnum(j))),j=1,el-1),
     &               (trim(elnam(elnum(j))),j=el+1,NELM),
     &               (trim(cmol(i)),i=1,NMOLE),
     &               ('S'//trim(short_name(i)),i=1,NDUST),
     &               ('n'//trim(short_name(i)),i=1,NDUST),
     &               ('eps'//trim(elnam(elnum(j))),j=1,el-1),
     &               ('eps'//trim(elnam(elnum(j))),j=el+1,NELM),
     &               'dust/gas','dustVol/H','Jstar(W)','Nstar(W)'

      !-------------------------------------
      ! ***  run chemistry on structure  ***
      !-------------------------------------
      eldust = 0.Q0
      mu = muH
      do i=Nfirst,Nlast,Ninc
        Tg      = Tgas(i)
        p       = press(i) 
        nHges   = nHtot(i)
        eps0(:) = estruc(i,:)

        !--- run chemistry (+phase equilibrium)    ---
        !--- iterate to achieve requested pressure ---
        do 
          if (model_pconst) nHges = p*mu/(bk*Tg)/muH
          if (model_eqcond) then
            call EQUIL_COND(nHges,Tg,eps,Sat,eldust,verbose)
          endif  
          call GGCHEM(nHges,Tg,eps,.false.,0)
          kT = bk*Tg
          nges = nel
          do j=1,NELEM
            nges = nges + nat(j)
          enddo
          do j=1,NMOLE
            nges = nges + nmol(j)
          enddo
          pges = nges*kT
          muold = mu
          mu = nHges/pges*(bk*Tg)*muH
          if (.not.model_pconst) exit
          print '("mu=",2(1pE12.5))',muold/amu,mu/amu
          if (ABS(mu/muold-1.0)<1.E-5) exit
        enddo  

        !--- compute supersat ratios and nucleation rates ---
        call SUPERSAT(Tg,nat,nmol,Sat)
        if (hasW) then
          call NUCLEATION('W',Tg,dust_vol(iW),nat(W),
     &                    Sat(iW),Jstar,Nstar)
        else
          Jstar = 0
          Nstar = 9.e+99
        endif  

        !--- compute dust/gas density ratio ---
        rhog  = nHges*muH
        rhod  = 0.0
        dustV = 0.0
        do jj=1,NDUST
          rhod  = rhod  + nHges*eldust(jj)*dust_mass(jj)
          dustV = dustV + eldust(jj)*dust_Vol(jj)
          out(jj) = LOG10(MIN(1.Q+300,MAX(1.Q-300,Sat(jj))))
          if (ABS(Sat(jj)-1.Q0)<1.E-10) out(jj)=0.Q0
        enddo  

        print'(i4," Tg[K] =",0pF8.2,"  n<H>[cm-3] =",1pE10.3)',
     >        i,Tg,nHges

        write(*,1010) ' Tg=',Tg,' n<H>=',nHges,
     &                ' p=',pges/bar,' mu=',mu/amu,
     &                ' dust/gas=',rhod/rhog
        !print*,pges,press(i)
        print*
        write(70,2010) Tg,nHges,pges,
     &       LOG10(MAX(1.Q-300, nel)),
     &      (LOG10(MAX(1.Q-300, nat(elnum(jj)))),jj=1,el-1),
     &      (LOG10(MAX(1.Q-300, nat(elnum(jj)))),jj=el+1,NELM),
     &      (LOG10(MAX(1.Q-300, nmol(jj))),jj=1,NMOLE),
     &      (out(jj),jj=1,NDUST),
     &      (LOG10(MAX(1.Q-300, eldust(jj))),jj=1,NDUST),
     &      (LOG10(eps(elnum(jj))),jj=1,el-1),
     &      (LOG10(eps(elnum(jj))),jj=el+1,NELM),
     &       LOG10(MAX(1.Q-300, rhod/rhog)),
     &       LOG10(MAX(1.Q-300, dustV)),
     &       LOG10(MAX(1.Q-300, Jstar)), 
     &       MIN(999999.99999,Nstar)

        if (verbose>0) read(*,'(a1)') char

      enddo  

      close(70)

 1000 format(4(' eps(',a2,') = ',1pD8.2))
 1010 format(A4,0pF8.2,3(a6,1pE9.2),1(a11,1pE9.2))
 2000 format(9999(1x,A19))
 2010 format(0pF20.6,2(1pE20.6),9999(0pF20.7))
      end  

