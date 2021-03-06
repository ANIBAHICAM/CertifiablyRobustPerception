function solution = tls_shape_alignment_tf_gnc(problem,varargin)

    params = inputParser;
    params.CaseSensitive = false;
    params.addParameter('divFactor', 1.4, @(x) isscalar(x));
    params.parse(varargin{:});
    divFactor = params.Results.divFactor;

    % GNC-TLS shape alignment translation free
    N = problem.N;
    barc2 = 1.0;
    yalmip('clear')
    t0 = tic;

    allPoints = 1:N;  
    weights = ones(N,1);
    stopTh = 1e-20;
    maxSteps = 1e5;
    divFactor = divFactor;
    itr = 0;
    pre_f_cost = inf;
    f_cost = inf;
    cost_diff = inf;

    while itr < maxSteps && cost_diff > stopTh
        % fix weights and solve for s, R, t using SOS relaxation
        if max(abs(weights)) < 1e-6
            disp('weights vanish, GNC failed.');
            break;
        end
        
        problem.weights = weights;
        wls_solution = shape_alignment_tf_outlier_free(problem);
        residuals = wls_solution.residuals; 
        % f_cost = sum(min(residuals,barc2)); % this is the TLS cost
        f_cost = weights' * residuals;
        if itr < 1
            maxResidual = max(residuals);
            mu = max(1 / ( 5 * maxResidual / barc2 - 1 ), 1e-6);
            cprintf('Keywords', 'maxResidual=%g, set mu=%g.\n',maxResidual, mu);
        end

        % update weights in closed-form
        th1 = (mu+1)/mu * barc2;
        th2 = (mu)/(mu+1) * barc2; % th1 > th2
        for i = 1:N
            if residuals(i) - th1 >= 0
                weights(i) = 0;
            elseif residuals(i) - th2 <= 0
                weights(i) = 1;
            else
                weights(i) = sqrt( barc2*mu*(mu+1)/residuals(i) ) - mu;
                assert(weights(i)>= 0 && weights(i) <=1, 'weights calculation wrong!');
            end
        end
         % increase mu and compute cost difference
         cost_diff = abs(f_cost -pre_f_cost);
         mu = mu * divFactor;
         itr = itr + 1;
         pre_f_cost = f_cost;
    end

    f_est = sum(min(residuals,barc2)); % this is the TLS cost
    s_est = wls_solution.s_est;
    R_est = wls_solution.R_est;
    t_est = wls_solution.t_est;
    t_gnc = toc(t0);

    solution.type = 'GNC-TLS';
    solution.weights = weights;
    theta_est = zeros(N,1);
    theta_est(weights > 0.5) = 1;
    theta_est(weights < 0.5) = -1;
    solution.theta_est = theta_est;
    solution.s_est = s_est;
    solution.R_est = R_est;
    solution.t_est = t_est;
    solution.itr = itr;
    solution.divFactor = divFactor;
    solution.t_gnc = t_gnc;
    solution.f_est = f_est;
    solution.detectedOutliers = allPoints(theta_est<0);

    % print some info
    fprintf('============================== GNC-TLS ================================\n')
    fprintf('f_est = %g, divFactor=%g, itr=%d, t_gnc=%g[s].\n',f_est,divFactor,solution.itr,t_gnc);
    fprintf('=======================================================================\n')



end