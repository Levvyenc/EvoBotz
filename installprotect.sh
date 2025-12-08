#!/bin/bash

repair_protection() {
    clear
    echo "Memperbaiki proteksi panel..."
    sleep 2

    # Restore backup files
    if [ -f "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php.backup" ]; then
        cp /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php.backup /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php
    fi

    if [ -f "/var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php.backup" ]; then
        cp /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php.backup /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php
    fi

    # Remove added middleware lines
    sed -i '/use Pterodactyl\\Http\\Middleware\\AdminProtection;/d' /var/www/pterodactyl/app/Http/Controllers/Controller.php
    sed -i '/$this->middleware(AdminProtection::class);/d' /var/www/pterodactyl/app/Http/Controllers/Controller.php
    sed -i "/'admin.protection' => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\AdminProtection::class,/d" /var/www/pterodactyl/app/Http/Kernel.php

    # Remove middleware file if exists
    rm -f /var/www/pterodactyl/app/Http/Middleware/AdminProtection.php

    cd /var/www/pterodactyl
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear
    php artisan config:clear

    echo "Proteksi berhasil dihapus! Panel kembali normal."
    sleep 2
}

# Main execution
if [ "$1" = "repair" ]; then
    repair_protection
else
    # Install protection
    clear
    echo "Menginstall proteksi panel..."
    sleep 2

    # Create backups
    cp /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php /var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php.backup
    cp /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php /var/www/pterodactyl/app/Http/Controllers/Admin/UsersController.php.backup

    # Fix UsersController - allow user ID 1 full access
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
        $user = auth()->user();
        
        if ($user->id !== 1) {
            // Non-admin users can only see themselves
            $users = $this->repository->findWhere([['id', '=', $user->id]]);
            return view('admin.users.index', ['users' => $users]);
        }
        
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

    # Fix ServerController
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
use Pterodactyl\Transformers\Api\Client\ServerTransformer;

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
            $servers = $user->servers()->get();
            return $this->fractal->collection($servers)
                ->transformWith($this->getTransformer(ServerTransformer::class))
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

    cd /var/www/pterodactyl
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear
    php artisan config:clear

    echo "Proteksi berhasil diinstall!"
    echo "User ID 1 memiliki akses penuh."
    echo "User lain hanya bisa melihat dan mengelola akun/server sendiri."
    echo ""
    echo "Jika ada error, jalankan: ./installprotect.sh repair"
    sleep 3
fi
