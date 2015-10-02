function outputParams=Image2Mesh(inputParams)

%% NIRFAST PATH
% Define new path
if isfield(inputParams,'useothernirfast')
    NIRFASTPath=inputParams.nirfastDir
    MESHINGPath=inputParams.nirfastMeshingDir
else
    NIRFASTPath=fullfile('..','NIRFast')
    MESHINGPath=fullfile('..','NIRFastMeshing')
end

% Add path
addpath(genpath(NIRFASTPath));
addpath(genpath(MESHINGPath));

%% CHECK I/O
if isfield(inputParams,'labelmap')
    inputpath = inputParams.labelmap
else
    rmpath(genpath(NIRFASTPath))
    rmpath(genpath(MESHINGPath));
    errordlg('Select an input label map', 'File Error')
    error('File Error: missing input (label map)')
end
if isfield(inputParams,'mesh')
    outputpath = inputParams.mesh
else
    rmpath(genpath(NIRFASTPath))
    rmpath(genpath(MESHINGPath));
    errordlg('Select an output mesh', 'File Error')
    error('File Error: missing output (mesh)')
end


% READ IMAGE
img = cli_imageread(inputpath)
mask = img.pixelData;


% %% READ PARAMETERS
% % File info
% param.Filename = inputpath;
% param.Format = 'NRRD';
% param.DataType = img.metaData.type; % 'short'

% % Compression info
% % TODO : understand those
% param.CompressedData = 'true';
% param.ObjectType = 'image';
% param.BinaryData = 'true';
% param.ByteOrder = 'false';
% param.CompressedDataSize = -1; % 35327
% param.DataFile = 'LOCAL';
% param.BitDepth = 16;
% param.HeaderSize = 359;

% Volume Information
param.AnatomicalOrientation = 'LPS' % 'LPI'
param.CenterOfRotation = [0,0,0];
param.NumberOfDimensions = str2num(img.metaData.dimension); % 3
dim = sscanf(img.metaData.sizes, '%f')';
param.Dimensions = dim; % [103,115,130]
offset = strrep(img.metaData.space_origin,'(',' ');
offset = strrep(offset,',',' ');
offset = strrep(offset,')',' ');
offset = sscanf(offset, '%f')';
param.Offset = offset; % [126.9220,2.6726,-78.2673]
% TODO : correct transform
param.TransformMatrix = [-1,0,0;0,-1,0;0,0,1]; %img.ijkToLpsTransform
spacedir = strrep(img.metaData.space_directions,'(',' ');
spacedir = strrep(spacedir,',',' ');
spacedir = strrep(spacedir,')',' ');
spacedir = sscanf(spacedir, '%f')';
spacedir = reshape(spacedir, param.NumberOfDimensions, []);
x=spacedir(1,1)*param.TransformMatrix(1,1);
y=spacedir(2,2)*param.TransformMatrix(2,2);
z=spacedir(3,3)*param.TransformMatrix(3,3);
param.PixelDimensions(1) = x; %(0.73884);
param.PixelDimensions(2) = y; %(0.73884);
param.PixelDimensions(3) = z; %(1)
param.PixelSpacing(1) = x; %(0.73884);
param.PixelSpacing(2) = y; %(0.73884);
param.SliceThickness  = z; %(1);

% Mesh Parameters
minsize = min(x, min(y,z));
param.cell_size = 2*minsize; % (1.4777);
param.cell_radius_edge = inputParams.cellradiusedge; % (3.0)
param.facet_size = 2*minsize; % (1.4777);
param.facet_angle = inputParams.facetangle; % (25.0)
param.facet_distance = inputParams.facetdistance; % (3.0)
param.special_subdomain_label = (0); % TODO ? label of region to be refined. If this is set to zero, no subdomain resizing will be performed
param.special_subdomain_size  = (0); % TODO ? size of tetrahedron for the special subdomain label
% param.medfilter = 0; % TODO ? apply a median filter to iron out speckle noises of images
% param.pad = 0; % TODO ? Add a zero padding to all XY dimensions

%% WRITE MESHES
% Write CGAL mesh
param.tmppath = inputParams.outputdir;
param.delmedit = 0;
if (exist('RunCGALMeshGenerator'))
    [e p] = RunCGALMeshGenerator(mask,param);
else
    rmpath(genpath(NIRFASTPath))
    rmpath(genpath(MESHINGPath));
    errordlg('RunCGALMeshGenerator function does not exist. Check that your path to NIRFast Meshing is correct.', 'Matlab Error')
    error('Matlab Error: RunCGALMeshGenerator function does not exist. Check that your path to NIRFast Meshing is correct.')
end

% Optimize mesh
q1 = simpqual(p, e, 'Min_Sin_Dihedral');
if isfield(inputParams,'optimizemesh')
    [genmesh.ele genmesh.node mat] = call_improve_mesh_use_stellar(e, p);
    q2 = simpqual(genmesh.node, genmesh.ele, 'Min_Sin_Dihedral');
else
    genmesh.ele = e;
    genmesh.node = p;
    if size(e,2) > 4
        mat = e(:,5);
    else
        mat = ones(size(e,1),1);
    end
end
genmesh.ele(:,5) = mat;
genmesh.nnpe = 4;
genmesh.dim = 3;

% Write Nirfast mesh
switch inputParams.meshtype
    case 'Standard'
        meshtype = 'stnd';
    case 'Fluorescence'
        meshtype = 'fluor';
    case 'Spectral'
        meshtype = 'spec';
    case 'BEM'
        meshtype = 'stnd_bem';
    case 'BEM Fluorescence'
        meshtype = 'fluor_bem';
    case 'BEM Spectral'
        meshtype = 'spec_bem';
    case 'SPN'
        meshtype = 'stnd_spn';
    otherwise
        error('This type of Nirfast mesh is not supported!');
end
nirfastMeshPath = fullfile(inputParams.outputdir,'nirfast_mesh');
solidmesh2nirfast(genmesh,nirfastMeshPath,meshtype);

% Write VTK mesh
% outputpath = fullfile(inputParams.outputdir,'polydata_me.vtk'); % Uncomment to save in outputdir
nirfast2vtk(nirfastMeshPath,outputpath,'polydata');

%% CLEAN
% Remove path
rmpath(genpath(NIRFASTPath))
rmpath(genpath(MESHINGPath));

% Delete files
% TODO ?

%% Help for reading/writing parameters
%
% Reading input parameters
%
%  integer, integer-vector, float, float-vector, double, double-vector, string, string-enumeration, file:
%    value=inputParams.name;
%  string-vector:
%    value=cli_stringvectordecode(inputParams.name);
%  point-vector:
%    value=cli_pointvectordecode(inputParams.name);
%  boolean:
%    value=isfield(inputParams,'name');
%  image:
%    value=cli_imageread(inputParams.name);
%  transform:
%    value=cli_lineartransformread(inputParams.name);
%   or (for generic transforms):
%    value=cli_transformread(inputParams.name);
%  point:
%    values_LPS=cli_pointvectordecode(inputParams.name);
%    [pointDim pointCount]=size(values_LPS);
%  region:
%    values=cli_pointvectordecode(inputParams.name);
%    [regionDim regionCount]=size(values_LPS);
%    center_LPS=[values(1:3,regionIndex); 1];
%    radius_LPS=abs([values(4:6,regionIndex); 1]);
%  measurement:
%    value=cli_measurementread(inputParams.name);
%  geometry:
%    value=cli_geometryread(inputParams.name);
%    Important: in the CLI definition file the following attribute shall be added to the geometry element: fileExtensions=".ply"
%    See https://subversion.assembla.com/svn/slicerrt/trunk/MatlabBridge/src/Examples/MeshScale/ for a complete example.
%
%  Notes:
%    - Input and file (image, transform, measurement, geometry) parameter names are defined by the <longflag> element in the XML file
%    - Output parameter names are defined by the <name> element in the XML file
%    - For retrieving index-th unnamed parameter use inputParams.unnamed{index+1} instead of inputParams.name
%
%
% Writing output parameters
%
%  integer, integer-vector, float, float-vector, double, double-vector, string, string-enumeration, file:
%    outputParams.name=value;
%  image:
%    cli_imagewrite(inputParams.name, value);
%  transform:
%    cli_lineartransformwrite(inputParams.name, value);
%   or (for generic transforms):
%    cli_transformwrite(inputParams.name, value);
%  measurement:
%    cli_measurementwrite(inputParams.name, value);
%  geometry:
%    cli_geometrywrite(inputParams.name, value);
%    Important: in the CLI definition file the following attribute shall be added to the geometry element: fileExtensions=".stl"
%    See https://subversion.assembla.com/svn/slicerrt/trunk/MatlabBridge/src/Examples/MeshScale/ for a complete example.
%
