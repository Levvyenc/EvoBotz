#!/bin/bash

install_protection() {
    clear
    echo "Menginstall proteksi panel..."
    sleep 2

    cp /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php.backup
    cp /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php.backup
    cp /var/www/pterodactyl/app/Http/Controllers/Controller.php /var/www/pterodactyl/app/Http/Controllers/Controller.php.backup

    cat > /tmp/AdminProtection.php << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminProtection
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        $route = $request->route();
        
        if (!$user) {
            return $next($request);
        }
        
        $adminRoutes = [
            'admin.users.create',
            'admin.users.store',
            'admin.users.destroy',
            'admin.settings.*',
            'admin.nests.*',
            'admin.locations.*',
            'admin.nodes.*',
        ];
        
        $currentRoute = $route->getName();
        
        foreach ($adminRoutes as $protectedRoute) {
            if (fnmatch($protectedRoute, $currentRoute)) {
                if ($user->id !== 1) {
                    abort(403, 'Administrator privileges required');
                }
            }
        }
        
        return $next($request);
    }
}
EOF

    sudo mv /tmp/AdminProtection.php /var/www/pterodactyl/app/Http/Middleware/AdminProtection.php

    cat > /tmp/ServerController.php << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Pterodactyl\Repositories\Eloquent\ServerRepository;
use Pterodactyl\Services\Servers\ServerDeletionService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\DeleteServerRequest;

class ServerController extends ClientApiController
{
    private ServerDeletionService $deletionService;
    private ServerRepository $repository;

    public function __construct(ServerDeletionService $deletionService, ServerRepository $repository)
    {
        parent::__construct();
        $this->deletionService = $deletionService;
        $this->repository = $repository;
    }

    public function index(GetServerRequest $request): array
    {
        $user = $request->user();
        
        if ($user->id !== 1) {
            $servers = $request->user()->servers->filter(function (Server $server) use ($user) {
                return $server->owner_id === $user->id;
            })->values();
            
            return $this->fractal->transformWith($this->getTransformer(ServerTransformer::class))
                ->collection($servers)
                ->toArray();
        }
        
        return parent::index($request);
    }

    public function delete(DeleteServerRequest $request, Server $server)
    {
        $user = $request->user();
        
        if ($user->id !== 1 && $server->owner_id !== $user->id) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }
        
        $this->deletionService->handle($server);
        return new Response('', 204);
    }
}
EOF

    sudo mv /tmp/ServerController.php /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php

    cat > /tmp/UsersController.php << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Pterodactyl\Models\User;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UsersController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected UserRepositoryInterface $repository,
        protected UserUpdateService $updateService
    ) {
    }

    public function index(): View
    {
        return view('admin.users.index', [
            'users' => $this->repository->setSearchTerm(request()->input('query'))->getAllUsers(),
        ]);
    }

    public function view(User $user): View
    {
        $currentUser = auth()->user();
        
        if ($currentUser->id !== 1 && $currentUser->id !== $user->id) {
            abort(403, 'Access denied');
        }
        
        return view('admin.users.view', [
            'user' => $user,
            'servers' => $user->servers,
        ]);
    }

    public function create(): View
    {
        $currentUser = auth()->user();
        
        if ($currentUser->id !== 1) {
            abort(403, 'Only user ID 1 can create users');
        }
        
        return view('admin.users.new');
    }

    public function store(UserFormRequest $request): RedirectResponse
    {
        $currentUser = auth()->user();
        
        if ($currentUser->id !== 1) {
            abort(403, 'Only user ID 1 can create users');
        }
        
        $user = $this->creationService->handle($request->normalize());
        $this->alert->success(trans('admin/user.alerts.user_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        $currentUser = auth()->user();
        
        if ($currentUser->id !== 1 && $currentUser->id !== $user->id) {
            abort(403, 'You can only edit your own profile');
        }
        
        $this->updateService->handle($user, $request->normalize());
        $this->alert->success(trans('admin/user.alerts.user_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function destroy(User $user): RedirectResponse
    {
        $currentUser = auth()->user();
        
        if ($currentUser->id !== 1) {
            abort(403, 'Only user ID 1 can delete users');
        }
        
        if ($user->id === 1) {
            abort(403, 'Cannot delete primary administrator');
        }
        
        $this->deletionService->handle($user);
        $this->alert->success(trans('admin/user.alerts.user_deleted'))->flash();

        return redirect()->route('admin.users');
    }
}
EOF

    sudo mv /tmp/UsersController.php /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php

    sed -i '/namespace.*Controller;/a\use Pterodactyl\\Http\\Middleware\\AdminProtection;' /var/www/pterodactyl/app/Http/Controllers/Controller.php

    sed -i '/public function __construct()/a\        $this->middleware(AdminProtection::class);' /var/www/pterodactyl/app/Http/Controllers/Controller.php

    sed -i "/protected \$routeMiddleware = \[/a\        'admin.protection' => \\Pterodactyl\\Http\\Middleware\\AdminProtection::class," /var/www/pterodactyl/app/Http/Kernel.php

    cd /var/www/pterodactyl
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear

    echo "Proteksi berhasil diinstall!"
    sleep 2
}

install_protection
