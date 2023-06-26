      SUBROUTINE UNPERT(IPAIR)
*
*
*       Unperturbed two-body motion.
*       ----------------------------
*
      Include 'kspars.h'
      INCLUDE 'common6.h'
      include 'timing.h'
      REAL*8  UI(4),UIDOT(4),A_EIN,CL2
      INTEGER  RES
*     Warning!: saved value is unsafe for parallel
      SAVE TCALL
      DATA TCALL /0.0D0/
      LOGICAL LBRAKE
*
*
*       Set first component & c.m. index and semi-major axis.
      I1 = 2*IPAIR - 1
      I2 = 2*IPAIR
      I = N + IPAIR
      SEMI = -0.5D0*BODY(I)/H(IPAIR)
*      
      CL2 = CLIGHT**2
*
*       Add elapsed unperturbed Kepler periods and update the time T0(I1).
      TK = TWOPI*SEMI*SQRT(SEMI/BODY(I))
      IF (TIME - T0(I1).LT.2.0E+09*TK) THEN
          K = NINT((TIME - T0(I1))/TK)
      ELSE
          K = 0
          NPRECT = NPRECT + 1
      END IF
      T0(I1) = TIME
*
*       Reset unperturbed counter if > 2*10**9 and update the frequency.
      IF (NKSPER.GT.2000000000.OR.NKSPER.LT.0) THEN
          NKSPER = 0
          NPRECT = NPRECT + 1
      END IF
      NKSPER = NKSPER + K
*
*       Include case of tidal dissipation or partial reflection (suppressed).
      IF (TDOT2(IPAIR).GE.0.0D0) THEN
*         IF (KZ(25).GT.0.AND.ABS(TDOT2(IPAIR).GT.1.0E-10) THEN
*             DT = 0.0
*             GO TO 10
*         END IF
*       Ensure perturbation check at least once every c.m. step (KSTAR < 11).
          IF (KZ(27).GT.0) THEN
              IF (KSTAR(I).LT.11) THEN
                  IF (STEP(I1).LT.TK) THEN
                      IF (STEP(I1).LT.0.0001*STEP(I)) GO TO 9
                  END IF
                  IF (TIME - T0(I).GT.2.0*STEP(I1)) THEN
                      DT = MIN(3.0D0*STEP(I1),STEP(I))
                      KPERT = 0
                      JCL = 0
                      GO TO 20
                  END IF
              END IF
          END IF
      END IF
*
*       Evaluate interval for unperturbed motion (GAMMA < GMIN).
    9 KPERT = 1
      IP = IPAIR
*     Copy JCL from IPAIR and restore value 
      call cputim(tt1)
      CALL TPERT(IPAIR,GMIN,DT)
      call cputim(tt2)
      if(rank.eq.0)tttp = tttp + (tt2-tt1)*60.
      JCL = IPAIR
      IPAIR = IP
*
*       Restore KS indicator and re-initialize if interval < period.
      IF (DT.LT.TK) THEN
*       Form perturber list and restart KS motion if required.
          CALL KSLIST(IPAIR)
          IF (LIST(1,I1).GT.0) THEN
*       Transform to apocentre variables in case of tidal dissipation.
              IF (R(IPAIR).LT.SEMI) THEN
                  NP = LIST(1,I1)
                  LIST(1,I1) = 0
*       Do not allow backwards integration on switch from unperturbed motion.
                  CALL KSPERI(IPAIR)
                  LIST(1,I1) = NP
                  CALL KSAPO(IPAIR)
              END IF
              KSLOW(IPAIR) = 1
              CALL RESOLV(IPAIR,1)
              CALL KSPOLY(IPAIR,1)
*       Include differential correction (experimental 10/02).
              JLIST(1) = I
              NNB = LIST(1,I1)
              DO 12 L = 1,NNB
                  JPERT(L) = LIST(L+1,I1)
   12         CONTINUE
              CALL NBPOT(1,NNB,POT1)
              JLIST(1) = I1
              JLIST(2) = I1 + 1
              CALL NBPOT(2,NNB,POT2)
*             if(rank.eq.0)
*    &        WRITE (6,13)  NAME(I1), POT1-POT2, GAMMA(IPAIR)
*  13         FORMAT ('  CORRECT    NAM DPHI G ',I6,1P,2E10.2)
              DETMP = POT2 - POT1
              EMERGE = EMERGE + DETMP
              BE(3) = BE(3) + DETMP
              GO TO 30
          END IF
          IR = 1
          GO TO 28
      END IF
*
*       Check for tidal dissipation (peri & apocentre included; skip merger).
   20 IF (KZ(27).GT.0.AND.
     &   (SEMI.LT.RMIN.OR.TDOT2(IPAIR).GT.0.0D0).AND.
     &   (KSTAR(I).EQ.0.OR.KSTAR(I).EQ.-1).AND.
     &   (NAME(I).GT.0)) THEN
*
*       Compare pericentre and effective capture distance.
          ECC2 = (1.0 - R(IPAIR)/SEMI)**2 +
     &                                    TDOT2(IPAIR)**2/(BODY(I)*SEMI)
          ECC = SQRT(ECC2)
          RP = SEMI*(1.0D0 - ECC)
          RT = 4.0*MAX(RADIUS(I1),RADIUS(I1+1))
*
*       Specify circularization index (skip SPIRAL but include CHAOS).
          ICIRC = 0
          IF (KZ(27).EQ.1.AND.TTOT.GT.TCALL) THEN
              IF (RP.LT.RT) ICIRC = 1
              TCALL = TTOT + 0.01
          ELSE IF (RP.LT.2.5*RT.AND.KSTAR(I).EQ.0.AND.
     &        TTOT.GT.TCALL) THEN
*       Perform occasional checks of TC (NB! small periods).
              CALL TCIRC(RP,ECC,I1,I1+1,ICIRC,TC)
              TCALL = TTOT + 0.01
          ELSE IF (KSTAR(I).EQ.-1) THEN
              ICIRC = 1
          END IF
*
*       See whether dissipation is active (A*(1 - E) < 4*MAX(R) & E > 0.002).
*         IF (RP.LT.0.99*RT.AND.ECC.GT.0.002) THEN
          IF (ICIRC.GT.0.AND.ECC.GT.0.002) THEN
*       Transform to pericentre if R > A (KSAPO works both ways with PI/2).
              IF (R(IPAIR).GT.SEMI) THEN
                  CALL KSAPO(IPAIR)
              END IF
*       Implement energy loss at pericentre (exit on collision).
              CALL KSTIDE(IPAIR,RP)
              IF (IPHASE.LT.0) GO TO 30
              SEMI = -0.5D0*BODY(I)/H(IPAIR)
              TK = TWOPI*SEMI*SQRT(SEMI/BODY(I))
              PD = TK*TSTAR*365.24D6
*       Assign one Kepler period for active state and impose TDOT2 > 0.
              IF (R(IPAIR).LT.0.99*RT.AND.KSTAR(I).NE.10) THEN
                  STEP(I1) = TK
                  TDOT2(IPAIR) = 1.0E-20
              ELSE
*       Define apocentre and set 1/2 period for inactive or synchronous case.
                  CALL KSAPO(IPAIR)
                  STEP(I1) = 0.5*TK
*       Note next unperturbed check at apocentre since T'' < 0 in KSAPO.
                  IF (ABS(RT - RP)/RT.GT.0.1.AND.KZ(27).LE.1) THEN
      if(rank.eq.0)WRITE(6,625)
     &   TTOT,STEP(I1),I,IPAIR,LIST(1,I1),
     &   NAME(I1),NAME(I2),NAME(I),KSTAR(I1),KSTAR(I2),KSTAR(I),
     &   BODY(I1)*ZMBAR,BODY(I2)*ZMBAR,ECC,SEMI,HI,GAMMA(IPAIR),
     &   PD,RADIUS(I1)*SU,RADIUS(I2)*SU,R(IPAIR)*SU,RP*SU,RT*SU
 625  FORMAT(1X,' INACTIIVE PHASE UNP T DT ',1P,2E13.5,' I IP NPERT',
     &   I10,2I6,' NM1,2,S=',3I10,' KW1,2,S=',3I4,' M1,2[M*]',2E13.5,
     &   ' e,a=',2E13.5,' H, GAMMA=',2E13.5,
     &   ' PD, R1,2,SEP,RP,RT[R*]=',6E13.5)
                  END IF
                  IF (ECC.LT.0.002.AND.SEMI.LT.0.01*RMIN) THEN
                      KSTAR(I) = 10
                      TEV(I) = TIME
*     ks MPI communicatin: KSTAR
*                     call ksparmpi(K_store,K_int,K_KSTAR,I,0,KSTAR(I))
*     ks MPI communicatin: TEV
*                     call ksparmpi(K_store,K_real8,K_TEV,I,0,TEV(I))
                  END IF
              END IF
*             if(rank.eq.0)print*,' goto 30 unpert '
              GO TO 30
          END IF
      END IF
*
*       Check for Roche overflow from synchronous orbit (but KSTAR < 13).
      IR = 0
      IF (KSTAR(I).EQ.13.AND.MIN(TEV(I1),TEV(I1+1)).LT.TIME + DT) THEN
          IR = -1
      END IF
      IF (KSTAR(I).GT.13) IR = 1
      IF (KZ(34).GT.0.AND.(KSTAR(I).GE.10.AND.KSTAR(I).LE.12)) THEN
          TM = MIN(TEV(I1),TEV(I1+1),TEV(I))
          IF (TM.LT.TIME) THEN
              CALL TRFLOW(IPAIR,DTR)
*       Exit if ROCHE is indicated (change 16/08/2006).
*             IF (DTR.LT.STEP(I1)) THEN
*                 CALL ROCHE(IPAIR)
*       Exit on coalescence (KPERT > 0 would cause trouble).
*                 IF (IPHASE.LT.0) GO TO 30
*             ELSE
*                 IR = 1
*             END IF
              IR = 1
              IF (DTR.LT.STEP(I1)) GO TO 30
*
              IF (DTR.GT.TK) THEN
                  DT = MIN(DTR,DT)
                  KPERT = 2
              END IF
          ELSE
              IR = 1
          END IF
      END IF
*
*       Check for GR braking for compact object binaries RSp March 2019
           HI = H(IPAIR)
           SEMI = -0.5*BODY(I)/HI
           ECC2 = (1.0-R(IPAIR)/SEMI)**2+TDOT2(IPAIR)**2/(BODY(I)*SEMI)
           ECC = SQRT(ECC2)
           QPERI = SEMI*(1.0 - ECC)
        LBRAKE =KZ273.EQ.3.AND.
     &    KSTAR(I1).GE.10.AND.KSTAR(I1).LE.14.AND.
     &    KSTAR(I2).GE.10.AND.KSTAR(I2).LE.14.AND.
     &    HI.LT.0.D0.AND.ECC.GT.0.D0
        IF (LBRAKE) THEN
*       GR breaking for compact obj. define new binary type March 2019
           A_EIN = 3.0*TWOPI*BODY(I)/(SEMI*CL2*(1-ECC2))
           TORB = TWOPI*SQRT(SEMI**3/BODY(I))
           DTGW(IPAIR) = STEP(I1)
           RSCHW = 2.0*BODY(I)/CLIGHT**2
           RES = 0
           KMIN = 0
           CALL GW_DECISION(SEMI,BODY(I1),BODY(I2),
     &              CLIGHT,ECC,DTGW(IPAIR),RES,TGR,KMIN)
           STEP(I1) = STEP(I1)/2**KMIN
           DTGW(IPAIR) = STEP(I1)
*       Special binary type -25 for GR shrinking binary
           IF(RES.EQ.1) THEN
              KSTAR(I) = -25
              CALL KSTIDE(IPAIR,QPERI)
      if(rank.eq.0)WRITE(6,665)
     &   RES,KMIN,TTOT,DTGW(IPAIR),STEP(I1),I,IPAIR,LIST(1,I1),
     &   NAME(I1),NAME(I2),NAME(I),KSTAR(I1),KSTAR(I2),KSTAR(I),
     &   BODY(I1)*ZMBAR,BODY(I2)*ZMBAR,ECC,SEMI,QPERI,RSCHW,
     &   H(IPAIR),GAMMA(IPAIR),A_EIN,TORB,TGR
 665  FORMAT(1X,' GR TIDES RES KMIN T DTGW STEP',2I4,1P,3E13.5,
     &   ' I IP NPERT',
     &   I10,2I6,' NM1,2,S=',3I10,' KW1,2,S=',3I4,' M1,2[M*]',2E13.5,
     &   ' e,a,QP,RS[NB]=',4E13.5,' H, GAMMA=',2E13.5,
     &   ' A_EIN, TORB, TGR(PM)=',3E13.5)
           END IF 
*       Prepare coal flag if PERI < 50 R_SCHW
            SEPMRG = 2.5D1*RSCHW
            IF(DABS(QPERI).LT.SEPMRG) THEN
              PRINT *,'COLL DUE TO GW UNPERT QPERI CLIGHT RSCH', 
     &                QPERI, CLIGHT, RSCHW 
              IPHASE = -1
              GO TO 30 
           END IF           
        END IF
*
*       Perform general two-body collision test.
      IF (KZ(19).GE.3.AND.NAME(I).GT.0) THEN
          RI = 0.0
          DO 26 K = 1,4
              UI(K) = U0(K,IPAIR)
              UIDOT(K) = UDOT(K,IPAIR)
              RI = RI + UI(K)**2
   26     CONTINUE
          CALL PERI(UI,UIDOT,RI,BODY(I1),BODY(I1+1),QPERI)
          IF (QPERI.LT.0.75*(RADIUS(I1) + RADIUS(I1+1))) THEN
c$$$*       Obtain KS variables at pericentre before coalescence to one body.
c$$$              CALL KSPERI(IPAIR)
c$$$              KSPAIR = IPAIR
c$$$*       Set indicator for skipping ECOLL updating in COAL.
c$$$              IQCOLL = -2
c$$$              CALL CMBODY(2)
c$$$              IF (IPHASE.LT.0) GO TO 30
             IPHASE = -1
             GO TO 30
          END IF
      END IF
*
*       Specify a conservative number of unperturbed orbits from TPERT.
      IF (KPERT.GT.0.AND.DT.GT.0.0) THEN
*       Ensure that next look-up time is not exceeded (option #27).
          IF (KZ(27).GT.0.AND.KPERT.GT.1) THEN
              TM = MIN(TEV(I1),TEV(I1+1))
              IF (TM - T0(I1).GT.0.0.AND.TM - T0(I1).LT.0.5*DT) THEN
                  NWARN = NWARN + 1
                  IF (rank.eq.0.and.NWARN.LT.1000) THEN
                      WRITE (25,27)  IPAIR, KSTAR(I1), KSTAR(I1+1),
     &                               KSTAR(I), TM-T0(I1), STEP(I1)
   27                 FORMAT (' UNPERT WARNING!   IPAIR  K*(I1) K*(I2)',
     &                     ' K*(ICM) TEVNXT[NB] STEP(I1)[NB]',
     &                     I12,3I4,1P,2E26.17,0P)
                      CALL FLUSH(25)
                  END IF
                  DT = MIN(2.0*(TM - T0(I1)),DT)
                  DT = MAX(DT,TK,STEPX)
              END IF
          END IF
*       Adopt c.m. step instead if integer argument exceeds 10**9.
          IF (DT.LT.2.0E+09*TK) THEN
              K = 1 + INT(0.5D0*DT/TK)
*       Restrict Kepler period to c.m. step (case of very wide orbit).
              STEP(I1) = FLOAT(K)*MIN(TK,STEP(I))
          ELSE
              STEP(I1) = STEP(I)
          END IF
*       Include optional treatment for spiralling of chaotic binary orbit.
          IF (KZ(27).GT.1.AND.KSTAR(I).EQ.-2) THEN
*       Ensure pericentre position after possible perturbed motion.
              IF (R(IPAIR).GT.SEMI) THEN
                  CALL KSRECT(IPAIR)
*       Reduce eccentric anomaly by pi for inward motion.
                  IF (TDOT2(IPAIR).LT.0.0D0) THEN
                      CALL KSAPO(IPAIR)
                  END IF
*       Transform from outward motion (anomaly < pi) to exact pericentre.
                  CALL KSPERI(IPAIR)
              END IF
              CALL SPIRAL(IPAIR)
              IF (IPHASE.LT.0) GO TO 30
          END IF
      END IF
*
*       Check merger condition before continuing (skip small Roche steps).
   28 IF (KZ(15).GT.0.AND.IR.GE.0.AND.TIME+STEP(I1).GT.TBLOCK) THEN
          IF (STEP(I).LT.DTMIN) THEN
              CALL IMPACT(I)
          ELSE IF (JCL.GT.0.AND.STEP(I).LT.10.0*DTMIN) THEN
              CALL HISTAB(IPAIR,JCL,PMIN,RSTAB)
              IF (RSTAB.LT.PMIN) THEN
                  CALL IMPACT(I)
              END IF
*       Include a more generous test for massive quadruples.
          ELSE IF (JCL.GT.N) THEN
              FAC = 2.0*(BODY(I) + BODY(JCL))/BODYM
              IF (STEP(I).LT.FAC*DTMIN) THEN
                  CALL HISTAB(IPAIR,JCL,PMIN,RSTAB)
                  IF (RSTAB.LT.PMIN) THEN
                      CALL IMPACT(I)
                  END IF
              END IF
          END IF
      END IF
*
*       Check collision criterion for special case.
      IF (KZ(27).EQ.-1) THEN
          ECC2 = (1.0 - R(IPAIR)/SEMI)**2 +
     &                                TDOT2(IPAIR)**2/(BODY(I)*SEMI)
          ECC = SQRT(ECC2)
          QPERI = SEMI*(1.0 - ECC)
          RFAC = 2.0
          I2 = I1 + 1
          IF (QPERI.LT.RFAC*MAX(RADIUS(I1),RADIUS(I2))) THEN
              J1 = I1
              IF (RADIUS(I2).GT.RADIUS(I1)) J1 = I2
              FAC = 0.5*BODY(I)/BODY(J1)
*       Adopt collision criterion of Kochanek (Ap.J. 385, 604, 1992).
              RCOLL = 1.7*FAC**0.3333*RADIUS(J1)
              IF (QPERI.LT.RCOLL) THEN
                  CALL TOUCH(IPAIR,I1,I2,RCOLL)
              END IF
          END IF
      END IF
*
   30 CONTINUE
*
      RETURN
*
      END
      
