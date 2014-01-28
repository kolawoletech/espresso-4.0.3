!
! Copyright (C) 2001-2007 Quantum-ESPRESSO PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!----------------------------------------------------------------------
subroutine add_for_charges (ik, uact)
!----------===============-----------------------------------------------
  !
  ! This subroutine calculates dS/du P_c [x, H-eS] |psi>
  !
#include "f_defs.h"

  USE ions_base, ONLY : nat, ityp, ntyp => nsp
  use pwcom
  USE becmod, ONLY: calbec
  USE noncollin_module, ONLY : noncolin, npol
  USE kinds, only : DP
  USE uspp_param, only: nh
  use phcom
  implicit none
  !
  !   The dummy variables
  !

  integer :: ik, mode
  ! input: the k point
  ! input: the actual perturbation
  complex(DP) :: uact (3 * nat)
  ! input: the pattern of displacements
  !
  !   And the local variables
  !

  integer :: na, nb, mu, nu, ikk, ikq, ig, igg, nt, ibnd, ijkb0, &
       ikb, jkb, ih, jh, ipol, is
  ! counter on atoms
  ! counter on modes
  ! the point k
  ! the point k+q
  ! counter on G vectors
  ! auxiliary counter on G vectors
  ! counter on atomic types
  ! counter on bands
  ! auxiliary variable for counting
  ! counter on becp functions
  ! counter on becp functions
  ! counter on n index
  ! counter on m index
  ! counter on polarizations

  real(DP), parameter :: eps = 1.d-12

  complex(DP), allocatable :: ps1 (:,:), ps2 (:,:,:), aux (:)
  complex(DP), allocatable :: ps1_nc (:,:,:), ps2_nc (:,:,:,:)
  ! the scalar product
  ! the scalar product
  ! a mesh space for psi
  complex(DP), allocatable :: bedp(:,:), aux1(:,:), alphapp(:,:,:)
  complex(DP), allocatable :: bedp_nc(:,:,:), alphapp_nc(:,:,:,:)

  logical :: ok
  ! used to save time

  allocate (aux ( npwx))
  allocate (aux1( npwx*npol, nbnd))
  IF (noncolin) THEN
     allocate (bedp_nc( nkb, npol, nbnd) )
     allocate (alphapp_nc (nkb, npol, nbnd,3))
     allocate (ps1_nc ( nkb, npol, nbnd))    
     allocate (ps2_nc ( nkb, npol, nbnd , 3))    
  ELSE
     allocate (bedp( nkb, nbnd) )
     allocate (alphapp (nkb,nbnd,3))
     allocate (ps1 ( nkb , nbnd))    
     allocate (ps2 ( nkb , nbnd , 3))    
  ENDIF
  if (lgamma) then
     ikk = ik
     ikq = ik
  else
     call infomsg ('add_for_charges', 'called for lgamma .eq. false')
  endif
  if (lsda) current_spin = isk (ikk)
  !
  !   we first compute the coefficients of the vectors
  !
  if (noncolin) then
     ps1_nc   = (0.d0, 0.d0)
     ps2_nc   = (0.d0, 0.d0)
     alphapp_nc = (0.d0,0.d0)
     bedp_nc = (0.d0,0.d0)
  else
     ps1   = (0.d0, 0.d0)
     ps2   = (0.d0, 0.d0)
     alphapp = (0.d0,0.d0)
     bedp = (0.d0,0.d0)
  endif
  aux1  = (0.d0, 0.d0)

  !
  ! first we calculate the products of the beta functions with dpsi 
  !
  IF (noncolin) THEN
     call calbec (npw, vkb, dpsi, bedp_nc)
  ELSE
     call calbec (npw, vkb, dpsi, bedp)
  ENDIF
  do ipol = 1, 3
     aux1=(0.d0,0.d0)
     do ibnd = 1, nbnd
        do ig = 1, npw
           aux1 (ig, ibnd) = dpsi(ig,ibnd) *           &
                tpiba * (0.d0,1.d0) *                  & 
                ( xk(ipol,ikk) + g(ipol,igk(ig)) )
        enddo
        if (noncolin) then
           do ig = 1, npw
              aux1 (ig+npwx, ibnd) = dpsi(ig+npwx,ibnd) *           &
                   tpiba * (0.d0,1.d0) *                  & 
                  ( xk(ipol,ikk) + g(ipol,igk(ig)) )
           enddo
        endif
     enddo
     if (noncolin) then
        call calbec ( npw, vkb, aux1, alphapp_nc(:,:,:,ipol) )
     else
        call calbec ( npw, vkb, aux1, alphapp(:,:,ipol) )
     endif
  enddo


  ijkb0 = 0
  do nt = 1, ntyp
     do na = 1, nat
        if (ityp (na) .eq.nt) then
           mu = 3 * (na - 1)
           if ( abs (uact (mu + 1) ) + &
                abs (uact (mu + 2) ) + &
                abs (uact (mu + 3) ) > eps) then
              do ih = 1, nh (nt)
                 ikb = ijkb0 + ih
                 do jh = 1, nh (nt)
                    jkb = ijkb0 + jh
                    do ipol = 1, 3
                       do ibnd = 1, nbnd
                          if (noncolin) then
                             if (lspinorb) then
                                ps1_nc(ikb,1,ibnd)=ps1_nc(ikb,1,ibnd) +    &
                                     (qq_so (ih, jh, 1, nt) *              &
                                     alphapp_nc(jkb, 1, ibnd, ipol) +      &
                                     qq_so (ih, jh, 2, nt) *               &
                                     alphapp_nc(jkb, 2, ibnd, ipol) )*     &
                                     uact (mu + ipol)
                                ps1_nc(ikb,2,ibnd)=ps1_nc(ikb,2,ibnd) +    &
                                     (qq_so (ih, jh, 3, nt) *              &
                                     alphapp_nc(jkb, 1, ibnd, ipol) +      &
                                     qq_so (ih, jh, 4, nt) *               &
                                     alphapp_nc(jkb, 2, ibnd, ipol) )*     &
                                     uact (mu + ipol)
                                ps2_nc(ikb,1,ibnd,ipol)=                   &
                                               ps2_nc(ikb,1,ibnd,ipol) +   &
                                     (qq_so (ih, jh, 1, nt) *              &
                                     bedp_nc (jkb, 1, ibnd) +              &
                                     qq_so (ih, jh, 2, nt) *               &
                                     bedp_nc (jkb, 2, ibnd) )*(0.d0,-1.d0) *  &
                                     uact (mu + ipol) * tpiba
                                ps2_nc(ikb,2,ibnd,ipol)= &
                                               ps2_nc(ikb,2,ibnd,ipol) +      &
                                     (qq_so (ih, jh, 3, nt) *                 &
                                     bedp_nc (jkb, 1, ibnd) +                 &
                                     qq_so (ih, jh, 4, nt) *                  &
                                     bedp_nc (jkb, 2, ibnd) )*(0.d0,-1.d0)* &
                                     uact (mu + ipol) * tpiba
                             else
                                do is=1,npol
                                   ps1_nc(ikb,is,ibnd)=ps1_nc(ikb,is,ibnd) + &
                                       qq (ih, jh, nt) *                     &
                                       alphapp_nc(jkb, is, ibnd, ipol) *     &
                                       uact (mu + ipol)
                                   ps2_nc(ikb,is,ibnd,ipol)=                 &
                                       ps2_nc(ikb,is, ibnd, ipol) +          &
                                       qq (ih, jh, nt) * (0.d0, -1.d0) *     &
                                       bedp_nc (jkb, is, ibnd) *             &
                                       uact (mu + ipol) * tpiba
                                end do
                             endif
                          else
                             ps1 (ikb, ibnd) = ps1 (ikb, ibnd) +     &
                                  qq (ih, jh, nt) *                  &
                                  alphapp(jkb, ibnd, ipol) *         &
                                  uact (mu + ipol)
                             ps2 (ikb, ibnd, ipol) = ps2 (ikb, ibnd, ipol) + &
                                  qq (ih, jh, nt) *                          &
                                   (0.d0, -1.d0) *                           &
                                   bedp (jkb, ibnd) *                        &
                                   uact (mu + ipol) * tpiba
                          endif
                       enddo
                    enddo
                 enddo
              enddo
           endif
           ijkb0 = ijkb0 + nh (nt)
        endif
     enddo
  enddo
  !
  !      This term is proportional to beta(k+q+G)
  !
  if (nkb.gt.0) then
     if (noncolin) then
        call ZGEMM ('N', 'N', npw, nbnd*npol, nkb, &
         (1.d0, 0.d0), vkb, npwx, ps1_nc, nkb, (1.d0, 0.d0) , dvpsi, npwx)
     else
        call ZGEMM ('N', 'N', npw, nbnd*npol, nkb, &
         (1.d0, 0.d0), vkb, npwx, ps1, nkb, (1.d0, 0.d0) , dvpsi, npwx)
!        dvpsi = matmul(vkb,ps1) + dvpsi
     endif
  endif
  !
  !      This term is proportional to (k+q+G)_\alpha*beta(k+q+G)
  !
  do ikb = 1, nkb
     do ipol = 1, 3
        ok = .false.
        do ibnd = 1, nbnd
           if (noncolin) then
              ok = ok .or. (abs (ps2_nc (ikb, 1, ibnd, ipol) ) .gt.eps) &
                      .or. (abs (ps2_nc (ikb, 2, ibnd, ipol) ) .gt.eps)
           else
              ok = ok.or. (abs (ps2 (ikb, ibnd, ipol) ) .gt.eps)
           endif
        enddo
        if (ok) then
           do ig = 1, npw
              igg = igkq (ig)
              aux (ig) =  vkb(ig, ikb) * (xk(ipol, ikq) + g(ipol, igg) )
           enddo
           do ibnd = 1, nbnd
              if (noncolin) then
                 do ig = 1, npw
                    dvpsi(ig,ibnd)=ps2_nc(ikb,1,ibnd,ipol)*aux(ig)+ &
                                   dvpsi(ig,ibnd)
                    dvpsi(ig+npwx,ibnd)=ps2_nc(ikb,2,ibnd,ipol)*aux(ig)+  &
                                        dvpsi(ig+npwx,ibnd)
                 enddo
              else
                 do ig = 1, npw
                    dvpsi(ig,ibnd)=ps2(ikb,ibnd,ipol)*aux(ig)+dvpsi(ig,ibnd)
                 enddo
              endif
           enddo
        endif
     enddo
  enddo
!
!    Now dvpsi contains dS/du x |psi>
!

  deallocate (aux)
  deallocate (aux1)
  IF (noncolin) THEN
     deallocate (bedp_nc)
     deallocate (alphapp_nc)
     deallocate (ps1_nc)
     deallocate (ps2_nc)
  ELSE
     deallocate (bedp)
     deallocate (alphapp)
     deallocate (ps1)
     deallocate (ps2)
  END IF

  return
end subroutine add_for_charges
