classdef Fragment < handle
   properties (SetAccess = private)      
      config;        % structure holding calculation inputs
      dataPath;      % location of template and data files
      templateText;  % text from the template file
      gaussianFile;  % gaussian job (i.e. input) file (with charge keyword)
      fileprefix;    % prefix for files, without environment numbers
      
      natom   % number of atoms in fragment
      nelec   % number of electrons in the fragment
      Z       % (1,natom) atomic numbers of the atoms
      rcart   % (3,natom) cartesian coordinates of the atoms
      npar    % number of parameters in template file

      nbasis  % number of atomic (and molecular) basis functions
      H1      % (nbasis,nbasis) full H1 operator of fragment
      H1en;   % (nbasis,nbasis,natom) electron-nuclear interaction
      KE;   % (nbasis,nbasis) kinetic energy
      H2;     % (nbasis,nbasis,nbasis,nbasis) 2-elec interactions
      S;      % (nbasis,nbasis) overlap
      Hnuc;   % nuclear-nuclear interaction energy
            
      Ehf     % Hartree Fock energy
      MP2     % MP2 Energy
      Eorb    % (nbasis,1)      molecular orbital energies
      orb     % (nbasis,nbasis) molecular orbital coefficients
      dipole  % (3,1)   dipole moment of molecule
      mulliken % (1,natom)  mulliken charge on the atoms

      nenv    %  numer of environments
      env     % (1,nenv)             environments
      H1Env   % (nbasis,nbasis,nenv) H1 due to environment
              %  full H1 in environment = H1 + H1Env(:,:,ienv)
      HnucEnv % (1,nenv)             Hnuc in environment

      EhfEnv   % (1,nenv)        Hartree-Fock energy in env
      MP2Env   % (1,nenv)        MP2 energy in env
      EorbEnv; % (nbasis,nenv)   molecular orbital energies in env
      orbEnv;  % (nbasis,nbasis,nenv) molecular orbitals in env
      dipoleEnv % (3,nenv) dipole moment in the environment
      
      basisAtom  % (nbasis,1) atom # on which the function is centered 
      basisType  % (nbasis,1) l quantum number: 0=s 1=p 2=d 3=d etc
      basisSubType % (nbasis,1) m quantum number: s=1 p=3 d=6 (cartesian)
      basisNprims  % number of primitives in this function
      basisPrims   % {nbasis,1} cell array of matrices of size (2,nprims)
                   %    with (1,:) being contraction coefficients and
                   %         (2,:) being primimitive exponents

   end
   properties
      % TODO Need to do something about these
      gaussianPath = 'c:\g09w';
      gaussianExe  = 'g09.exe';
   end
   methods (Access = private)
      initializeData(obj);
   end
   methods (Static)
      function res = defaultConfig()
         %  templateFile = name of template file, in dataPathIn
         %               [defaults to 'template.txt']
         %  basisSet = basis set keyword (Gaussian format)
         %               [defaults to 'STO-3G']
         %  method = Method that you want to use
         %              [defults to hf]
         %  charge = charge on the fragment
         %             [defaults to 0]
         %  spin   = spin (multiplicity) of the fragment,
         %             using Gaussian convention
         %             [defaults to 1]
         res.template = 'template';
         res.basisSet = 'STO-3G';
         res.method   = 'hf';
         res.charge   = 0;
         res.spin     = 1;
         res.par      = [];
      end
      [found,fileprefix] = findCalc(dataPath,config)
      [MP2, Ehf, Eorb, orb, Nelectrons,  Z, rcart, ...
         dipole, mulliken, ...
       atom, type, subtype, nprims, prims ] = readfchk(fid1)
      [Eorb, orb, atom, Nelectrons, Ehf] = oldreadfchk(fid1)
      [S, H1, KE, H2, Enuc] = readpolyatom(fid1)
   end
   methods
      function res = Fragment(dataPathIn, configIn)
         %  dataPath = directory (including c:\ etc) for data storage
         %               do not include a \ at end of paths
         %               [defaults to 'data']
         %  configIn = configuration structure
         %               [defaults to 'Fragment.defaultConfig();
         if (nargin < 1)
            res.dataPath = 'data';
         else
            res.dataPath = dataPathIn;
         end
         if (nargin < 2)
            res.config = Fragment.defaultConfig();
         else
            res.config = configIn;
         end
         [found,res.fileprefix] = ...
            Fragment.findCalc(res.dataPath,res.config);
         if (found)
            ftemp = [res.fileprefix,'_calc.mat'];
            prefixsave = res.fileprefix;
            dataPathsave = res.dataPath;
            load(ftemp, 'resFile' );
            res = resFile;
            res.fileprefix = prefixsave;
            res.dataPath = dataPathsave;
         else
            res.templateText = fileread([res.dataPath,filesep,...
               res.config.template,'.tpl']);
            res.natom = size( strfind(res.templateText, 'ATOM'), 2);
            res.npar = size( strfind(res.templateText, 'PAR'), 2);
            nparIn = size(res.config.par,1) * size(res.config.par,2);
            if (nparIn ~= res.npar)
               error(['template has ',num2str(res.npar),' parameters',...
                  ' while config contains ',num2str(nparIn),' pars']);
            end
            res.initializeData();
            resFile = res;
            Cfile = res.config;
            save([res.fileprefix,'_cfg.mat'],  'Cfile' );
            save([res.fileprefix,'_calc.mat'], 'resFile' );
            if (exist(res.fileprefix) ~= 7)
               mkdir(res.fileprefix);
            end
         end
         res.nenv = 0;
         % Set the environment array to have the correct class type
         res.env = Environment.empty(0,0);
      end
      function setEnvSize(obj,nenvIn)
         clear obj.env;
         obj.env(1,nenvIn) = Environment;
         obj.H1Env = zeros(obj.nbasis, obj.nbasis, nenvIn);
         obj.EhfEnv = zeros(1,nenvIn);
         obj.MP2Env = zeros(1,nenvIn);
         obj.EorbEnv = zeros(obj.nbasis, nenvIn);
         obj.orbEnv  = zeros(obj.nbasis,obj.nbasis,nenvIn);
         obj.dipoleEnv = zeros(3,nenvIn);
      end
   end % methods
end %
