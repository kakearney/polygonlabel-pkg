function [xl,yl] = polygonlabel(x, y, varargin)
%POLYGONLABEL Calculate coordinates for polygon label
%
% [xl,yl] = polygonlabel(x, y)
% [xl,yl] = polygonlabel(x, y, 'plot', true)
%
% This function was designed to label convex polygons on a map, where you
% want to find a nice open space within the polygon to place a label.  The
% "best" place to label often isn't the centroid of the polygon.
%
% This is designed to be used with cartesian coordinate polygons; project
% map polygons prior to calling.  For very complex polygons, I recommend
% reducing the number of vertices prior to calling this function, since
% extra vertices can increase computation time significantly.
%
% The underlying algorithm is based on Kang & Elhami, 2001, ("Using
% Shape Analyses for Placement of Polygon Labels", ESRI 2001 Int. User
% Conf).
%
% Input variables:
%
%   x:      x-coordinates of polygons, nan-delimited vectors with clockwise
%           external contours and counterclockwise inner contours (holes). 
%
%   y:      y-coordinates of polygons
%
% Optional input variables (passed as parameter/value pairs)
%
%   plot:   logical scalar.  If true, plots the polygon and
%           buffered-polygon as it is calculated (primarily for debugging
%           purposes).
%
% Output variables:
%
%   xl:     x coordinate of best label position
%
%   yl:     y coordinate of best label position

% Copyright 2015 Kelly Kearney

Opt.plot = false;
Opt = parsepv(Opt, varargin);

[xs,ys] = polysplit(x,y);
cw = ispolycw(xs,ys);
parea = cellfun(@(x,y) polyarea(x,y), xs, ys);

% Choose buffer step size based on area of outer polygon

step = sqrt(parea(1)/pi/10);
init = 0;

if nargin < 3
    Opt.plot = false;
end
if Opt.plot
    hfig = figure;
    [f,v] = poly2fv(x,y);
    hp = patch('faces', f, 'vertices', v);
    set(hp, 'facecolor', ones(1,3)*0.5, 'edgecolor', 'none');
    drawnow;
    hold on;
end

% Begin buffering-in loop

while 1
    
    % Test the initial buffer size.  If too big (buffer erases the entire
    % polygon), cut buffer size in half and try again.
    
    istoobig = true;
    while istoobig
    
        bwidth = init + step;

        [xb, yb] = bufferm2('xy', x, y, bwidth, 'in');

        if isempty(xb)
            step = step/2;
        else
            [xbs,ybs] = polysplit(xb,yb);
            areanew = cellfun(@(x,y) polyarea(x,y), xbs, ybs);
            
            istoobig = false;
        end
        if Opt.plot
            delete(findall(hfig, 'color', 'r'));
            line(xb, yb, 'color', 'r');
            title(num2str(bwidth));
            drawnow
        end
    end
    
    % Check to see if the convex hull of the biggest remaining polygon is
    % completely within the original polygon.
    
    [~, imax] = max(areanew);

    W = warning('off');
    dt = delaunayTriangulation(xbs{imax},ybs{imax});
    warning(W);
    k = convexHull(dt);
    xyhull = dt.Points(k,:);
    
    [xhull, yhull] = poly2cw(xyhull(:,1), xyhull(:,2));
    [sub,~] = polybool('-', xhull, yhull, x, y);
    
    % If we found an enclosed hull, break out of loop.  Otherwise, repeat
    % the process with a larger buffer.
    
    if isempty(sub) 
        break
    else
        init = init + step;
    end
    
end

% Calculate centroid of enclosed polygon

geom = polygeom(xbs{imax}, ybs{imax});
xl = geom(2);
yl = geom(3);


