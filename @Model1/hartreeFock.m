function [orb,Eorb,Ehf] = hartreeFock(obj,env,eps)
% Solve Hartree Fock equations
% Input:
%   obj:  Holds hamiltonian information (H1,H2,S,nelec,Hnuc,H1env,HnucEnv)
%          [see Fragment class for definitions of these properties]
%   env:   environment number (uses H1env(:,:,env) and HnucEnv(env))
%          [defaults to 0, with 0 meaning isolated fragment]
%   eps:   convergence criteria
%          [defaults to 1e-8]
% Output
%   orb:   (nbasis,nbasis) 
%            orbital coefficient matrix (atom basis #, mol orb #)
%   Eorb:  (nbasis,1)  molecular orbital energies
%   Ehf:    total Hartree-Fock energy

if (nargin < 2)
   env = 0;
end
if (nargin < 3)
   eps = 1.0e-8;
end

if (env == 0)
   H1 = obj.H1;
   Enuc = obj.Hnuc;
else
   H1 = obj.H1 + obj.H1Env(:,:,env);
   Enuc = obj.HnucEnv(1,env);
end
H2 = obj.H2;
S  = obj.S;
Nelec = obj.frag1.nelec;

[Nbasis,junk] = size(H1); %#ok<NASGU> %Getting size of basis set

 %step 3 -- Calculate transformation matrix (eq. 3.167)
X = inv(sqrtm(S));

 %step 4 -- Guess at density matrix -- all zeros right now
P = (eps*2)*ones(Nbasis); % Old density matrix
Pn = zeros(Nbasis); % New density matrix

%Begin iteration through 
while(max(max(abs(P - Pn))) > eps) %step 11 -- Test convergence
    
    P = Pn; %update P to be the new density matrix
    
    %step 5 -- Build 2-electron components of Fock matrix
    G = zeros(Nbasis);
    for i = 1:Nbasis
        for j = 1:Nbasis
            for k = 1:Nbasis
                for l = 1:Nbasis
                    
                G(i,j) = G(i,j) + P(k,l)*(H2(i,j,l,k)-(1/2)*H2(i,k,l,j));
           
                end
            end
        end
    end
    
    %step 6 -- Obtain F (fock matrix)
    F = H1 + G;
    
    %step 7 -- Calculate the transformed F matrix
    Ft = X'*F*X; %#ok<MINV>
    
    %step 8 -- Find e and the transformed expansion coefficient matrices
    [Ct1,e1] = eig(Ft);
	e2 = diag(e1);
	[e, i1] = sort(e2);
	Ct = Ct1(:,i1);
                       
    %step 9 -- Transform Ct back to C
    C = X*Ct; %#ok<MINV>
    
    %step 10 -- Calculate the new density matrix
    Pn = zeros(Nbasis);
    Cj = conj(C);
    for i = 1:Nbasis
        for j = 1:Nbasis
            for a = 1:(Nelec/2)
                Pn(i,j) = Pn(i,j) + (C(i,a)*Cj(j,a));
            end
            Pn(i,j) = Pn(i,j)*2;
        end
    end
end
%End of iteration of steps 5-11

P = Pn; %for convenience

%Step 12: Output

%Total energy
%3.184: E0 = 1/2 Sum(i,j) {P(j,i)[H1(i,j) + F(i,j)]}
Ee = 0;
for i = 1:Nbasis
    for j = 1:Nbasis
        Ee = Ee + P(j,i)*(H1(i,j)+F(i,j));
    end
end
Ehf = Ee/2 + Enuc;

%Orbital energies
Eorb = e;

%Molecular orbital components
orb = C;
end

%{
Adapted from "Modern quantum chemistry", by Attila Szab�, Neil S. Ostlund
Numbered equations also adapted from here.
1. Specify a molecule
2. Calculate S(i,j), H^core (H1), and (i j|k l)(H2)
    -These first two steps are done by Gaussian
3. Diagonalize overlap matrix S and obtain X from 3.167
    3.167: X = S^(-1/2)
4. Guess the density matrix P (first guess is zeros here)
5. Calculate matrix G of 3.154 from P and H2
    G(i,j) = Sum(k, l){P(k,l)[(i j|l k)-1/2(i k|l j)]}
6. Add G to core-Hamiltonian  to get Fock matrix
    3.154: F(i,j) = H1(i,j) + G(i,j)
7. Calculate transformed Fock matrix F' = X'(t)FX
8. Diagonalize F' to obtain C' and epsilon
9. Calculate C = XC'
10. Form new density matrix P from C w/ 3.145
    3.145: P(i,j) = 2 Sum(1-Nelec/2){C(i,a) C*(j,a)}
11. Has P converged to within eps?
    No? -> Step 5 w/ new P from 10.
    Yes? -> Step 12
12. Use resultant solution, represented by C,P,F to calculate outputs
%}
